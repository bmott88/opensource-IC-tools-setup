#!/bin/bash
set -e

NETLIST=$1
BASENAME="${NETLIST%.*}"

# check netlist input
if [ -z "$NETLIST" ]; then
    echo "Usage: $0 <.sch or .spice file>"
    exit 1
fi

# clean-up functions for program exit
cleanup() {
    rm -f \
        "${BASENAME}"_temp_*.spice \
        "${BASENAME}"_temp_*.csv \
        "${BASENAME}"_temp_*.spice.new \
        "${BASENAME}"_clean_*.csv \
        *_temp.log
}

interrupt_handler() {
    echo
    echo "Interrupted - cleaning up."
    cleanup
    exit 130
}

trap interrupt_handler INT TERM
trap cleanup EXIT

# copy netlist into local directory
echo "Copying spice netlist from ~/.xschem/simulations/"

if ! cp "$HOME/.xschem/simulations/$BASENAME.spice" .; then
    echo "Error: failed to copy $BASENAME.spice"
    exit 1
fi

echo "Netlist successfully copied into current directory"

# prompt user for process corner(s)
read -p "Select what process corner(s) you would like to simulate: (tt, ss, ff, sf, fs, all): " CORNER
echo ""

if [[ ! "$CORNER" =~ ^(tt|ss|ff|sf|fs|all)$ ]]; then
    echo "Invalid corner: $CORNER"
    exit 1
fi

# output filenames
TIMESTAMP=$(date +%s)
LOG="${BASENAME}_corner_${TIMESTAMP}.log"
if [ "$CORNER" = "all" ]; then
    MASTER_CSV="${BASENAME}_all_${TIMESTAMP}.csv"
else
    SINGLE_CSV="${BASENAME}_${CORNER}_${TIMESTAMP}.csv"
fi

# Function to convert CSV into single x-axis and multiple y-axis columns
clean_csv() {
    local INPUT_CSV=$1
    local OUTPUT_CSV=$2

    awk '{
        printf "%s", $1
        for (i=2; i<=NF; i+=2)
            printf " %s", $i
        print ""
    }' "$INPUT_CSV" > "$OUTPUT_CSV"
}

# function to run one corner simulation
corner_simulate() {

    local CORNER_NAME=$1

    local CSV="${BASENAME}_temp_${CORNER_NAME}.csv"
    local TEMPNETLIST="${BASENAME}_temp_${CORNER_NAME}.spice"
    local CLEANED_CSV="${BASENAME}_clean_${CORNER_NAME}.csv"
    local RUN_LOG="${CORNER_NAME}_temp.log"

    echo ""
    echo "========================================"
    echo "Simulating corner: ${CORNER_NAME}"
    echo "========================================"

    # create temp netlist
    cp "${BASENAME}.spice" "$TEMPNETLIST"

    # change corner in temp netlist
    sed -i \
        "s|^\([[:space:]]*\.lib[[:space:]]\+[^[:space:]]\+[[:space:]]\+\)[^[:space:]]\+|\1${CORNER_NAME}|" \
        "$TEMPNETLIST"

    # get nets to plot based on "save" command in netlist
    SAVE_VARS=$(awk '
        BEGIN { IGNORECASE=1 }

        /^[[:space:]]*save[[:space:]]+/ {
            sub(/^[[:space:]]*save[[:space:]]+/, "")
            print
            exit
        }
    ' "$TEMPNETLIST")

    if [ -z "$SAVE_VARS" ]; then
        echo "Error: corner ${CORNER_NAME}: no save command found" >&2
        return 1
    fi

    # insert "wrdata" after simulation type
    if ! awk \
        -v csv="$CSV" \
        -v save_vars="$SAVE_VARS" '
        BEGIN {
            IGNORECASE = 1
            inserted = 0
        }

        {
            print

            if (!inserted &&
                $1 ~ /^(dc|tran|ac|op|noise|tf|sens|disto)$/) {

                print "wrdata " csv " " save_vars
                inserted = 1
            }
        }

        END {
            if (!inserted)
                exit 1
        }
        ' "$TEMPNETLIST" > "${TEMPNETLIST}.new"
    then
        echo "Error: corner ${CORNER_NAME}: no supported simulation command found" >&2
        return 1
    fi

    mv "${TEMPNETLIST}.new" "$TEMPNETLIST"

    # run simulation
    echo "Running ngspice for ${CORNER_NAME}..."

    if ! ngspice -b "$TEMPNETLIST" > "$RUN_LOG" 2>&1; then
        echo "Error: corner ${CORNER_NAME} failed" >&2
        cat "$RUN_LOG" >&2
        return 1
    fi

    # check for output csv
    if [ ! -f "$CSV" ]; then
        echo "Error: corner ${CORNER_NAME} did not produce CSV" >&2
        cat "$RUN_LOG" >&2
        return 1
    fi

    clean_csv "$CSV" "$CLEANED_CSV"

    # concatenate log to master log
    {
        echo "========================================"
        echo "Corner: ${CORNER_NAME}"
        echo "========================================"
        cat "$RUN_LOG"
        echo ""
    } >> "$LOG"

    rm -f "$RUN_LOG"

    # handle csv output
    if [ "$CORNER" = "all" ]; then

        # Add corner name as final column.
        #
        # The first row is copied normally and receives
        # the "corner" header. All data rows receive the
        # actual corner name.

        if [ ! -f "$MASTER_CSV" ]; then

            awk -v corner="$CORNER_NAME" '
                NR == 1 {
                    print $0, "corner"
                    next
                }
                {
                    print $0, corner
                }
            ' "$CLEANED_CSV" > "$MASTER_CSV"

        else

            awk -v corner="$CORNER_NAME" '
                NR > 1 {
                    print $0, corner
                }
            ' "$CLEANED_CSV" >> "$MASTER_CSV"

        fi

        # Separate each corner with blank lines so that
        # gnuplot can also treat each corner as a dataset.
        #
        # Rebuild the spacing by inserting blank lines
        # before the newly appended corner data.

        if [ "$CORNER_NAME" != "tt" ]; then

            TEMP_MASTER="${MASTER_CSV}.tmp"

            awk -v corner="$CORNER_NAME" '
                BEGIN {
                    found = 0
                }

                {
                    if (!found && $NF == corner) {
                        print ""
                        print ""
                        found = 1
                    }

                    print
                }
            ' "$MASTER_CSV" > "$TEMP_MASTER"

            mv "$TEMP_MASTER" "$MASTER_CSV"

        fi
    else
        mv "$CLEANED_CSV" "$SINGLE_CSV"
    fi

    # remove temp files
    rm -f "$TEMPNETLIST" "$CSV"

    echo "Corner ${CORNER_NAME} completed successfully."
}

# run selected corners
if [ "$CORNER" = "all" ]; then

    for C in tt ss ff sf fs; do
        corner_simulate "$C"
    done

else

    corner_simulate "$CORNER"

fi


echo ""


# check that simulations actually created csv output
if [ "$CORNER" = "all" ]; then

    if [ -f "$MASTER_CSV" ]; then
        echo "CSV successfully created: $MASTER_CSV"
    else
        echo "CSV creation failed"
        exit 1
    fi

else
    if [ -f "$SINGLE_CSV" ]; then
        echo "CSV successfully created: $SINGLE_CSV"
    else
        echo "CSV creation failed"
        exit 1
    fi

fi

# optionally plot using gnuplot
read -p "Plot results? (y/n): " PLOT

if [ "$PLOT" = "y" ] || [ "$PLOT" = "Y" ]; then

    if ! command -v gnuplot >/dev/null 2>&1; then
        echo "Error: gnuplot is not installed or not in PATH"
        exit 1
    fi

    echo "Opening gnuplot..."

    if [ "$CORNER" = "all" ]; then

        # Number of numeric columns.
        # The final column is the corner name, so exclude it.
        NUM_COLS=$(awk '
            NR == 1 {
                print NF - 1
                exit
            }
        ' "$MASTER_CSV")

        gnuplot -p << EOF
set datafile separator " "

set title "Process Corner Comparison"
set xlabel "X"
set ylabel "Value"
set grid
set key outside

NCOLS = $NUM_COLS

plot \
    for [col=2:NCOLS] '$MASTER_CSV' index 0 using 1:col with lines title sprintf("tt - Trace %d", col-1), \
    for [col=2:NCOLS] '$MASTER_CSV' index 1 using 1:col with lines title sprintf("ss - Trace %d", col-1), \
    for [col=2:NCOLS] '$MASTER_CSV' index 2 using 1:col with lines title sprintf("ff - Trace %d", col-1), \
    for [col=2:NCOLS] '$MASTER_CSV' index 3 using 1:col with lines title sprintf("sf - Trace %d", col-1), \
    for [col=2:NCOLS] '$MASTER_CSV' index 4 using 1:col with lines title sprintf("fs - Trace %d", col-1)
EOF

    else

        NUM_COLS=$(awk 'NR == 1 {print NF; exit}' "$SINGLE_CSV")

        gnuplot -p << EOF
set datafile separator " "

set title "Process Corner: $CORNER"
set xlabel "X"
set ylabel "Value"
set grid
set key outside

NCOLS = $NUM_COLS

plot for [col=2:NCOLS] '$SINGLE_CSV' using 1:col with lines title sprintf("Trace %d", col-1)
EOF

    fi
fi

# organize output files
mkdir -p "cornerSim_data"
OUTPUT_DIR="cornerSim_data/${BASENAME}_${CORNER}"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/log"

mv "$LOG" "$OUTPUT_DIR/log"
mv "${BASENAME}.spice" "$OUTPUT_DIR"

if [ "$CORNER" = "all" ]; then
    mv "$MASTER_CSV" "$OUTPUT_DIR"
else
    mv "$SINGLE_CSV" "$OUTPUT_DIR"
fi

# inform user where output files are located
echo ""
echo "Output files placed in '$OUTPUT_DIR'"
