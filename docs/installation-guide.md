# Setting up the TinyTapeout Open-Source Toolchain

This covers installing **xschem**, **ngspice**, **magic**, and **netgen** natively from source, then wiring them up to both the **SkyWater sky130** and **IHP SG13G2** open PDKs. Instructions assume **Ubuntu/Debian Linux** (native or WSL2 on Windows).

---

## 1. Install build dependencies (Ubuntu/Debian)

```bash
sudo apt update
sudo apt upgrade
sudo apt install -y build-essential git m4 tcsh csh autoconf automake libtool \
  tcl-dev tk-dev libx11-dev libcairo2-dev libxpm-dev libgtk-3-dev \
  mesa-common-dev libglu1-mesa-dev libncurses-dev libreadline-dev \
  bison flex libxaw7-dev libx11-dev libxrender-dev \
  python3 python3-pip python3-venv \
  libopenmpi-dev zlib1g-dev
```

If your distro's packaged `xschem`, `ngspice`, `magic`, or `netgen` exist, remove them first. The packaged versions are almost always too old for use with the modern open PDKs:

```bash
sudo apt-get remove --purge xschem ngspice magic netgen 2>/dev/null
```

Pick a working directory for source builds, e.g. `~/eda-src`.

```bash
mkdir -p ~/eda-src && cd ~/eda-src
```

### Build and install xschem

```bash
git clone https://github.com/StefanSchippers/xschem.git
cd xschem
./configure
make -j$(nproc)
sudo make install
cd ..
```

### Build and install ngspice

Build with XSPICE and OSDI support, OSDI is required for the IHP SG13G2 PSP103 MOSFET model, and doesn't hurt sky130 use.

```bash
git clone https://git.code.sf.net/p/ngspice/ngspice ngspice_git
cd ngspice_git
./autogen.sh
mkdir release && cd release
../configure --with-x --enable-xspice --enable-cider --disable-debug \
  --enable-osdi --enable-klu --with-readline=yes
make -j$(nproc)
sudo make install
cd ../..
```

### Build and install magic

```bash
git clone https://github.com/RTimothyEdwards/magic.git
cd magic
./configure
make -j$(nproc)
sudo make install
cd ..
```

### Build and install netgen

```bash
git clone https://github.com/RTimothyEdwards/netgen.git
cd netgen
./configure
make -j$(nproc)
sudo make install
cd ..
```

---

## 2. Install the PDKs with `ciel`

Both **sky130** and **IHP SG13G2** are distributed as prebuilt, version-pinned packages via `ciel` (the successor to `volare`), you do **not** need to compile `open_pdks` yourself for either one.

```bash
sudo apt install pipx
pipx ensurepath
pipx install ciel
```

By default `ciel` installs into `~/.ciel`. It's common to instead set a `PDK_ROOT` explicitly and put it in your shell profile (`~/.bashrc`):

```bash
echo 'export PDK_ROOT=$HOME/eda/pdk' >> ~/.bashrc
source ~/.bashrc
mkdir -p "$PDK_ROOT"
```

Then check it was installed correctly by checking the version

```bash
ciel --version
```

### Install sky130

```bash
# list available versions (already sorted newest-first)
ciel ls-remote --pdk-family sky130

# enable a specific commit hash from that list
ciel enable --pdk-family sky130 <commit_hash>
```

This installs to `$PDK_ROOT/sky130A` (and `sky130B` if built with the ReRAM option).

> **Notes on the hash:**
> - It must be the **full** commit hash, not a shortened version like git allows, `ciel` has no short-hash support. Copy-paste it directly from the `ls-remote` output.
> - Only copy the hash itself, not the `(2026.06.05)`-style date shown next to it, that's just a human-readable timestamp, not part of the identifier.

### Install IHP SG13G2

```bash
ciel ls-remote --pdk-family ihp-sg13g2
ciel enable --pdk-family ihp-sg13g2 <commit_hash>
```

This installs to `$PDK_ROOT/ihp-sg13g2`. The same full-hash rules above apply.

---

### Installing `openvaf` from source (ONLY required for IHP SG13G2)

The IHP SG13G2 PDK uses Verilog-A compact models, including the PSP103 MOSFET model, which must be compiled into OSDI libraries for use with ngspice. The IHP PDK's `install.py` script invokes `openvaf` to build these models.

This section builds the community-maintained OpenVAF-Reloaded compiler from source

### Install LLVM 18

```bash
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 18
sudo apt install -y llvm-18 llvm-18-dev libclang-18-dev clang-18
```

Set LLVM 18 as the LLVM installation used by OpenVAF:

```bash
echo 'export LLVM_SYS_181_PREFIX=/usr/lib/llvm-18' >> ~/.bashrc
echo 'export PATH=/usr/lib/llvm-18/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

Verify the installation:

```bash
llvm-config-18 --version
clang-18 --version
```

Both should report LLVM 18.x.

### Install Rust

OpenVAF-Reloaded is written in Rust. Install Rust using `rustup`:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

When prompted, choose **Customize installation** and select the **complete** profile.

Then reload the Rust environment:

```bash
source ~/.cargo/env
```

Verify:

```bash
rustc --version
cargo --version
```

### Build OpenVAF-Reloaded

Clone the OpenVAF-Reloaded source repository:

```bash
cd ~/eda-src
git clone https://github.com/OpenVAF/OpenVAF-Reloaded.git
cd OpenVAF-Reloaded
```

Build the compiler using LLVM 18:

```bash
cargo build --release --features llvm18 --bin openvaf-r
```

The resulting compiler is:

```text
target/release/openvaf-r
```

Install it into the user's local executable directory:

```bash
mkdir -p ~/.local/bin
cp target/release/openvaf-r ~/.local/bin/
ln -sf ~/.local/bin/openvaf-r ~/.local/bin/openvaf
```

Verify that OpenVAF is available, the expected output is `OpenVAF-reloaded unkown`.

```bash
openvaf --version
```

### Compile the IHP SG13G2 Verilog-A models

Now run the IHP PDK's installation script:

```bash
cd "$PDK_ROOT/ihp-sg13g2/libs.tech/xschem"
python3 install.py
```

The script uses `openvaf` to compile the PDK's Verilog-A models into OSDI libraries. In particular, it creates the PSP103 NQS model required by the IHP MOSFET devices.

Verify that the model was created:

```bash
ls -lh "$PDK_ROOT/ihp-sg13g2/libs.tech/ngspice/osdi/psp103_nqs.osdi"
```

The IHP installation script also installs the PDK-specific ngspice configuration as `~/.spiceinit`. **Do not create a separate custom `~/.spiceinit`**, because doing so can prevent ngspice from loading the IHP OSDI models.

You can verify the symlink with:

```bash
ls -l ~/.spiceinit
```

It should point to the IHP PDK's ngspice configuration under `$PDK_ROOT/ihp-sg13g2/libs.tech/ngspice/`

At this point OpenVAF and the IHP PSP103 models are installed and ready for ngspice.

---

## 3. Wiring the tools to each PDK

### Selecting a PDK environment

Rather than typing `PDK`/`PDK_ROOT` every time, `ihp_env_setup` and `sky130_env_setup` can be sourced, which makes switching between a sky130 project and an IHP project painless, since each one just hardcodes its own PDK:

Set a default pdk to use, and add a line to your `~/.bashrc` file to select that pdk during start-up. Typical default is the sky130 pdk, but you may choose the IHP pdk if preferred.

```bash
cd ~/FILE/PATH/opensource-IC-tools-setup/pdk-env
cp .sky130_env_setup .ihp_env_setup $HOME
echo 'source ~/.sky130_env_setup' >> ~/.bashrc
source ~/.bashrc
```

If you would like to change to a different pdk just invoke `source ~/FILE/PATH/<pdk-env-file>`

### xschem

A **shell function that follows your current `$PDK` variable** is convenient when switching between projects as it lets you keep typing the plain `xschem`/`magic` command, and it automatically points at whichever PDK environment you have set (see below in  `Selecting a PDK environment`). Add to `~/.bashrc`:

```bash
xschem() {
  command xschem --rcfile "$PDK_ROOT/$PDK/libs.tech/xschem/xschemrc" "$@"
}
magic() {
  command magic -rcfile "$PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc" -d "Cairo" "$@"
}
```

`command xschem` / `command magic` tells bash to run the real binary rather than recursing into the function. `"$@"` passes through any extra arguments (like a filename to open). Note: double check the magic rcfile naming actually matches `$PDK.magicrc` for both PDKs (`sky130A.magicrc` and `ihp-sg13g2.magicrc` both do, as of writing).

Reload with `source ~/.bashrc`, then just run `xschem` or `magic` plain (no rcfile flags typed out each time).

### ngspice

Invoked automatically by xschem's "simulate" button once the `xschemrc` above is loaded (it sets the right `.spiceinit`/model search paths). For standalone use, make sure the PDK-managed ~/.spiceinit is installed. The IHP configuration loads the required PSP103 OSDI models automatically. Do not .include or source the binary .osdi files as SPICE netlists.

### netgen (LVS)

Netgen setup files live alongside the other tech files:

```bash
netgen -batch lvs "layout.spice layout_top" "schematic.spice schematic_top" \
  $PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl lvs_report.txt
```

Swap in `$PDK_ROOT/ihp-sg13g2/libs.tech/netgen/ihp-sg13g2_setup.tcl` for IHP designs.

(The command above expects real `layout.spice`/`schematic.spice` files to exist see the test version in [Verifying the setup]\(#verifying-the-setup) if you just want to confirm netgen + the PDK setup file load correctly, without having real netlists yet.)
