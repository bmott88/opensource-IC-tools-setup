v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 -20 0 20 {lab=Y}
N 0 -0 50 -0 {lab=Y}
N -50 -50 -40 -50 {lab=xxx}
N -50 -50 -50 50 {lab=xxx}
N -50 50 -40 50 {lab=xxx}
N -70 -0 -50 -0 {lab=xxx}
N -0 -100 -0 -80 {lab=VDD}
N 0 80 -0 100 {lab=VSS}
N -0 50 10 50 {lab=VSS}
N 10 50 10 80 {lab=VSS}
N 0 80 10 80 {lab=VSS}
N 0 -50 10 -50 {lab=VDD}
N 10 -80 10 -50 {lab=VDD}
N 0 -80 10 -80 {lab=VDD}
C {sky130_fd_pr/nfet_01v8.sym} -20 50 0 0 {name=M2
L=0.15
W=1  
nf=1 mult=1
model=nfet_01v8
spiceprefix=X
}
C {sky130_fd_pr/pfet_01v8.sym} -20 -50 0 0 {name=M1
L=0.15
W=1
nf=1 mult=1
model=pfet_01v8
spiceprefix=X
}
C {ipin.sym} -70 0 0 0 {name=p1 lab=A}
C {opin.sym} 50 0 0 0 {name=p2 lab=Y}
C {iopin.sym} 0 -100 3 0 {name=p3 lab=VDD}
C {iopin.sym} 0 100 1 0 {name=p4 lab=VSS}
