v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
C {inv.sym} 0 0 0 0 {name=x1}
C {lab_pin.sym} 0 -40 1 0 {name=p1 sig_type=std_logic lab=VDD}
C {lab_pin.sym} -50 0 0 0 {name=p2 sig_type=std_logic lab=IN}
C {lab_pin.sym} 80 0 2 0 {name=p3 sig_type=std_logic lab=OUT}
C {gnd.sym} 0 40 0 0 {name=l1 lab=0}
C {vsource.sym} -220 0 0 0 {name=V1 value=1.8 savecurrent=false}
C {vsource.sym} -160 0 0 0 {name=V2 value=0 savecurrent=false}
C {lab_pin.sym} -220 -30 1 0 {name=p4 sig_type=std_logic lab=VDD}
C {lab_pin.sym} -160 -30 1 0 {name=p5 sig_type=std_logic lab=IN}
C {gnd.sym} -160 30 0 0 {name=l2 lab=0}
C {gnd.sym} -220 30 0 0 {name=l3 lab=0}
C {sky130_fd_pr/corner.sym} 150 -130 0 0 {name=CORNER only_toplevel=true corner=tt}
C {code.sym} 150 40 0 0 {name=NGSPICE only_toplevel=false value="

.control
dc V2 0 1.8 0.001
plot v(out)
.endc

"}
