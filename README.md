# opensource-IC-tools-setup
Installation guide for open-source IC design tools including xschem, ngspice, magic VLSI, and netgen. Additional setup files and automation scripts are also included.

## Repository Contents
`docs` (Main guide and documentation)
* installation-guide.md

`misc` (Random changes to setup files)
* magic_bindkeys.txt
* xschemrc_changes.txt

`pdk-env` (Used to change selected PDK environment)
* ihp_env_setup
* sky130_env_setup

`scripts` (Used for simulation automation and parasitic extraction)
* cornerSim.sh
* monteCarlo.sh
* netgen_lvs.sh
* plotSim.sh
* run_lvs_extract.sh
* run_rcx.sh

`test-schematics` (Use to try out xschem and running simulations)
* ihp/
    * inv.sch
    * inv.sym
    * tb_inv.sch
* sky/
    * inv.sch
    * inv.sym
    * tb_inv.sch

## New Installation

FOR NEW INSTALL START HERE -> `docs/installation-guide.md`
