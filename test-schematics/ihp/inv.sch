v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -0 0 20 {lab=Y}
N 0 -0 90 0 {lab=Y}
N 0 -20 0 -0 {lab=Y}
N -50 -50 -40 -50 {lab=A}
N -50 -0 -50 50 {lab=A}
N -50 50 -40 50 {lab=A}
N -80 -0 -50 -0 {lab=A}
N -50 -50 -50 -0 {lab=A}
N 0 -50 10 -50 {lab=VDD}
N 10 -80 10 -50 {lab=VDD}
N 0 -80 10 -80 {lab=VDD}
N 0 -100 -0 -80 {lab=VDD}
N -0 50 10 50 {lab=xxx}
N 10 50 10 80 {lab=xxx}
N 0 80 10 80 {lab=xxx}
N 0 80 -0 100 {lab=xxx}
C {sg13g2_pr/sg13_lv_nmos.sym} -20 50 0 0 {name=M1
l=0.13u
w=0.15u
ng=1
m=1
model=sg13_lv_nmos
spiceprefix=X
}
C {sg13g2_pr/sg13_lv_pmos.sym} -20 -50 0 0 {name=M2
l=0.13u
w=0.15u
ng=1
m=1
model=sg13_lv_pmos
spiceprefix=X
}
C {iopin.sym} 0 -100 3 0 {name=p1 lab=VDD}
C {ipin.sym} -80 0 0 0 {name=p2 lab=A}
C {opin.sym} 90 0 0 0 {name=p3 lab=Y}
C {iopin.sym} 0 100 1 0 {name=p4 lab=VSS}
