#!/bin/bash
#Script to make running netgen lvs easier

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <extracted_netlist.spice> <original_netlist.spice>"
    exit 1
fi

if [ -z "$PDK_ROOT" ] || [ -z "$PDK" ]; then
    echo "Error: \$PDK_ROOT and \$PDK must be set (source your env file first, e.g. source env/sky130.env)"
    exit 1
fi

LVS_SPICE=$1
SCH_SPICE=$2

CELL="${SCH_SPICE%.spice}"

SETUP_TCL="${PDK_ROOT}/${PDK}/libs.tech/netgen/${PDK}_setup.tcl"

if [ ! -f "$SETUP_TCL" ]; then
    echo "Error: no netgen setup file found at $SETUP_TCL"
    echo "Check that \$PDK ('$PDK') is a valid PDK name and is installed under \$PDK_ROOT ('$PDK_ROOT')"
    exit 1
fi

netgen -batch lvs "${LVS_SPICE} ${CELL}" "${SCH_SPICE} ${CELL}" "${SETUP_TCL}"

echo "Done!"
