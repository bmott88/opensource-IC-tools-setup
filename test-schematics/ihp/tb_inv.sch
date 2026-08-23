v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {inv.sym} 0 0 0 0 {name=x1}
C {lab_pin.sym} 100 0 2 0 {name=p1 sig_type=std_logic lab=OUT}
C {lab_pin.sym} -60 0 0 0 {name=p2 sig_type=std_logic lab=IN}
C {lab_pin.sym} 0 -50 1 0 {name=p3 sig_type=std_logic lab=VDD}
C {gnd.sym} 0 50 0 0 {name=l1 lab=0}
C {vsource.sym} -200 0 0 0 {name=V1 value=1.8 savecurrent=false}
C {vsource.sym} -140 0 0 0 {name=V2 value=0 savecurrent=false}
C {gnd.sym} -140 30 0 0 {name=l2 lab=0}
C {gnd.sym} -200 30 0 0 {name=l3 lab=0}
C {lab_pin.sym} -200 -30 1 0 {name=p4 sig_type=std_logic lab=VDD}
C {lab_pin.sym} -140 -30 1 0 {name=p5 sig_type=std_logic lab=IN}
C {simulator_commands_shown.sym} 150 -140 0 0 {
name=Libs_Ngspice
simulator=ngspice
only_toplevel=false
value="
.lib cornerMOSlv.lib mos_tt
.lib cornerMOShv.lib mos_tt
.lib cornerHBT.lib hbt_typ
.lib cornerRES.lib res_typ
.lib cornerDIO.lib dio_tt
"
      }
C {simulator_commands_shown.sym} 160 50 0 0 {name=SimulatorNGSPICE
simulator=ngspice
only_toplevel=false 
value="
.param temp=27
.control
dc V2 0 1.8 0.001
plot v(out)
.endc
"}
