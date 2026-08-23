#!/bin/bash

# Usage: run_rcx.sh <cellname>
# where <cellname> is a magic layout (<cellname>.mag)

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <cellname>" >&2
    exit 1
fi

if [ -z "$PDK_ROOT" ] || [ -z "$PDK" ]; then
    echo "Error: \$PDK_ROOT and \$PDK must be set (source your env file first, e.g. source env/sky130.env)"
    exit 1
fi

if [ "$PDK" = "ihp-sg13g2" ]; then
    EXTRACT_FORMAT="ext2spice format cdl"
else
    EXTRACT_FORMAT="ext2spice lvs"
fi

PDK_PATH="${PDK_ROOT}/${PDK}/libs.tech/magic/${PDK}.magicrc"

if [ ! -f "$PDK_PATH" ]; then
    echo "Error: no magic rcfile found at $PDK_PATH" >&2
    echo "Check that \$PDK ('$PDK') is installed under \$PDK_ROOT ('$PDK_ROOT')" >&2
    exit 1
fi

if [ ! -f "${1}.mag" ]; then
    echo "Error: layout file ${1}.mag not found" >&2
    exit 1
fi

magic -rcfile "$PDK_PATH" -dnull -noconsole > ${1}_rcx_magic.log << EOF
drc off
locking disable
crashbackups stop
box 0 0 0 0
load $1
select top cell
flatten myflat
load myflat
cellname delete $1
cellname rename myflat $1
select top cell
extract path extfiles
extract unique notopports
extract all
ext2sim labels on
ext2sim -p extfiles
extresist tolerance 10
extresist
$EXTRACT_FORMAT
ext2spice cthresh 0.1
ext2spice extresist on
ext2spice -p extfiles -o ${1}_rcx.spice
quit -noprompt
EOF

rm -r extfiles
echo "Done!"
exit 0
