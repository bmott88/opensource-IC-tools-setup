#!/bin/bash
set -e

NETLIST=$1
BASENAME="${NETLIST%.*}"
CORNER_NAME="tt_mm"
PROGRESS_FILE="${BASENAME}_progress.tmp"

# check netlist input
if [ -z "$NETLIST" ]; then
    echo "Usage: $0 <.sch or .spice file>"
    exit 1
fi

# clean-up functions for program exit
cleanup() {
    # stop all background simulation jobs first
    local pids
    pids=$(jobs -pr)

    if [ -n "$pids" ]; then
        kill $pids 2>/dev/null || true
        wait $pids 2>/dev/null || true
    fi

    # remove temp files
    rm -f \
        "${BASENAME}"_temp_*.spice \
        "${BASENAME}"_temp_*.csv \
        "${BASENAME}"_temp_*.spice.new \
        "${BASENAME}"_clean_*.csv \
        *_temp.log \
        "${PROGRESS_FILE}" \
        "${PROGRESS_FILE}.lock"
}

interrupt_handler() {
    echo
    echo "Interrupted - stopping simulations and cleaning up."
    cleanup
    exit 130
}

trap interrupt_handler INT TERM
trap cleanup EXIT

# copy netlist into local directory
if ! cp "$HOME/.xschem/simulations/$BASENAME.spice" .; then
    echo "Error: failed to copy $BASENAME.spice"
    exit 1
fi

# monte-carlo settings
read -p "Monte Carlo runs: " RUNS

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [ "$RUNS" -le 0 ]; then
    echo "Error: runs must be a positive integer"
    exit 1
fi

echo "Available cores: $(nproc)"
read -p "Parallel simulations: " MAX_JOBS

if ! [[ "$MAX_JOBS" =~ ^[0-9]+$ ]] || [ "$MAX_JOBS" -le 0 ]; then
    echo "Error: parallel simulations must be a positive integer"
    exit 1
fi

if [ "$MAX_JOBS" -gt "$(nproc)" ]; then
    echo "Error: cannot use more than $(nproc) parallel simulations"
    exit 1
fi

echo
echo "Starting ${RUNS} Monte Carlo runs using ${MAX_JOBS} parallel simulations..."


# output filenames
TIMESTAMP=$(date +%s)
MASTER_CSV="${BASENAME}_mc_${TIMESTAMP}.csv"
LOG="${BASENAME}_mc_${TIMESTAMP}.log"

# progress checking
echo 0 > "$PROGRESS_FILE"

# function to convert csv into single x-axis and multiple y-axis
clean_csv() {
    local input_csv=$1
    local output_csv=$2

    awk '{
        printf "%s", $1
        for (i=2; i<=NF; i+=2)
            printf " %s", $i
        print ""
    }' "$input_csv" > "$output_csv"
}

# function to run one simulation
mc_simulate() {

    local RUN_ID=$1

    local CSV="${BASENAME}_temp_${RUN_ID}.csv"
    local TEMPNETLIST="${BASENAME}_temp_${RUN_ID}.spice"
    local CLEANED_CSV="${BASENAME}_clean_${RUN_ID}.csv"
    local RUN_LOG="${RUN_ID}_temp.log"

    # create temp netlist
    cp "${BASENAME}.spice" "$TEMPNETLIST"

    # change device corner
    sed -i \
        "s|^\([[:space:]]*\.lib[[:space:]]\+[^[:space:]]\+[[:space:]]\+\)[^[:space:]]\+|\1${CORNER_NAME}|" \
        "$TEMPNETLIST"

    # get nets specified by "save" command
    SAVE_VARS=$(awk '
        BEGIN { IGNORECASE=1 }

        /^[[:space:]]*save[[:space:]]+/ {
            sub(/^[[:space:]]*save[[:space:]]+/, "")
            print
            exit
        }
    ' "$TEMPNETLIST")

    if [ -z "$SAVE_VARS" ]; then
        echo "Error: Run ${RUN_ID}: no save command found" >&2
        return 1
    fi

    # add "wrdata" after simulation specification
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
        echo "Error: Run ${RUN_ID}: no supported simulation command found" >&2
        return 1
    fi

    mv "${TEMPNETLIST}.new" "$TEMPNETLIST"

    # run ngspice and check success
    if ! ngspice -b "$TEMPNETLIST" > "$RUN_LOG" 2>&1; then
        echo "Error: Run ${RUN_ID} failed" >&2
        cat "$RUN_LOG" >&2
        return 1
    fi

    # check if csv was generated
    if [ ! -f "$CSV" ]; then
        echo "Error: Run ${RUN_ID} did not produce CSV" >&2
        cat "$RUN_LOG" >&2
        return 1
    fi

    clean_csv "$CSV" "$CLEANED_CSV"

    # remove temp files
    rm -f "$TEMPNETLIST" "$CSV"

    # increment progress bar
    (
        flock 200
        count=$(cat "$PROGRESS_FILE")
        echo $((count + 1)) > "$PROGRESS_FILE"
    ) 200>"${PROGRESS_FILE}.lock"
}

# start simulations
for ((I=1; I<=RUNS; I++))
do

    mc_simulate "$I" &

    while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do

        COMPLETED=$(cat "$PROGRESS_FILE")

        BAR_LENGTH=30
        FILLED=$((COMPLETED * BAR_LENGTH / RUNS))
        EMPTY=$((BAR_LENGTH - FILLED))

        printf "\rProgress: ["

        printf "%${FILLED}s" "" | tr ' ' '#'
        printf "%${EMPTY}s" "" | tr ' ' '-'

        printf "] %d/%d" "$COMPLETED" "$RUNS"

        sleep 0.2
    done

done

# wait for all simulations to run while updating progress bar
while true
do

    RUNNING=$(jobs -r | wc -l)
    COMPLETED=$(cat "$PROGRESS_FILE")

    BAR_LENGTH=30
    FILLED=$((COMPLETED * BAR_LENGTH / RUNS))
    EMPTY=$((BAR_LENGTH - FILLED))

    printf "\rProgress: ["

    printf "%${FILLED}s" "" | tr ' ' '#'
    printf "%${EMPTY}s" "" | tr ' ' '-'

    printf "] %d/%d" "$COMPLETED" "$RUNS"

    if [ "$RUNNING" -eq 0 ]; then
        break
    fi

    sleep 0.2

done

wait

# final progress bar
printf "\rProgress: ["
printf "%${RUNS}s" "" | tr ' ' '#'
printf "] %d/%d\n" "$RUNS" "$RUNS"

echo "All simulations completed."

# merge all log files
for ((I=1; I<=RUNS; I++))
do
    if [ -f "${I}_temp.log" ]; then
        cat "${I}_temp.log" >> "$LOG"
        echo "" >> "$LOG"
    fi
done

rm -f *_temp.log

# merge all csv files
if [ ! -f "${BASENAME}_clean_1.csv" ]; then
    echo "Error: Run 1 did not produce a cleaned CSV"
    exit 1
fi

cp "${BASENAME}_clean_1.csv" "$MASTER_CSV"

for ((I=2; I<=RUNS; I++))
do
    if [ ! -f "${BASENAME}_clean_${I}.csv" ]; then
        echo "Error: Run ${I} did not produce a cleaned CSV"
        exit 1
    fi

    printf "\n\n" >> "$MASTER_CSV"
    cat "${BASENAME}_clean_${I}.csv" >> "$MASTER_CSV"
done

rm -f "${BASENAME}"_clean_*.csv

# optionally plot using gnuplot
read -p "Plot results? (y/n): " PLOT
if [ "$PLOT" = "y" ] || [ "$PLOT" = "Y" ]; then
    NUM_COLS=$(awk 'NR==1{print NF; exit}' "$MASTER_CSV")

    gnuplot -p << EOF
    set datafile separator " "
    NCOLS = $NUM_COLS

    plot for [col=2:NCOLS] '$MASTER_CSV' index 0 using 1:col with lines title sprintf("Run %d", col-1), \
        for [idx=1:$(($RUNS - 1))] for [col=2:NCOLS] '$MASTER_CSV' index idx using 1:col with lines notitle
EOF
fi

# organize output
mkdir -p "monteCarlo_data"
mkdir -p "monteCarlo_data/${BASENAME}"
mkdir -p "monteCarlo_data/${BASENAME}/log"

mv "$MASTER_CSV" "${BASENAME}.spice" "monteCarlo_data/${BASENAME}"
mv "$LOG" "monteCarlo_data/${BASENAME}/log"

echo "Output: monteCarlo_data/${BASENAME}"
