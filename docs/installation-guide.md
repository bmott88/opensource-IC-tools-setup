# Setting up the TinyTapeout Open-Source Toolchain

This covers installing **xschem**, **ngspice**, **magic**, and **netgen** natively from source, then wiring them up to both the **SkyWater sky130** and **IHP SG13G2** open PDKs. Instructions assume **Ubuntu/Debian Linux** (native or WSL2 on Windows).

---

## 1. Install build dependencies (Ubuntu/Debian)

```bash
sudo apt update
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

Create a `.spiceinit` file (used by ngspice on every run) in your home directory:

```bash
cat > ~/.spiceinit << 'EOF'
set ngbehavior=hsa
set ng_nomodcheck
EOF
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
python3 -m pip install --user --upgrade --no-cache-dir ciel
ciel --version
```

> **Note** `pip install --user` puts the `ciel` executable (and anything else installed this way: `pcpp`, `pygments`, etc.) in `~/.local/bin`, which usually isn't on your `PATH` by default on a fresh system. If `ciel --version` says "command not found," add this to `~/.bashrc` and reload your shell:
> ```bash
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
> source ~/.bashrc
> ```

By default `ciel` installs into `~/.ciel`. It's common to instead set a `PDK_ROOT` explicitly and put it in your shell profile (`~/.bashrc`):

```bash
export PDK_ROOT=$HOME/eda/pdk
mkdir -p "$PDK_ROOT"
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

### IHP-specific extra step: build the PSP103 OSDI model

The IHP SG13G2 MOSFET model (PSP103) needs to be compiled with `openvaf` into an `.osdi` binary that ngspice loads at runtime. The actual script (confirmed by directory listing) is `install.py`, not a shell script:

```bash
cd $PDK_ROOT/ihp-sg13g2/libs.tech/xschem
ls   # confirms install.py is present alongside xschemrc, sg13g2_pr, etc.
python3 install.py
```

This compiles `psp103_nqs.osdi` into the PDK's `ngspice/osdi/` directory and symlinks a PDK-specific `.spiceinit` into your home directory so IHP simulations work from any folder.

**This script requires the `openvaf` Verilog-A compiler to already be on your `PATH`.** If you see:

```
VerilogA compiler not found - install 'openvaf-r' or 'openvaf' to generate the necessary models
```

you need to install it manually first, see the next section, **Installing openvaf**, before re-running `install.py`.

---

## Installing `openvaf` (required for IHP SG13G2 only)

`openvaf` is **not** on GitHub Releases, despite the project living on GitHub the maintained fork is [OpenVAF/OpenVAF-Reloaded](https://github.com/OpenVAF/OpenVAF-Reloaded), but its precompiled binaries are hosted separately at:

**https://fides.fe.uni-lj.si/openvaf/download**

A few things that aren't obvious from the repo README:

- Binaries are named `openvaf-reloaded-<version>-linux_x64.tar.gz`, each is a **tarball**, not a standalone binary you can `chmod +x` directly. Extract it first.
- There are two lineages: files with `osdi_0.3` in the name are the older API; files with `osdi_0.4` (including the newest, unlabeled ones like `openvaf-reloaded-20260616...`) are the current one. ngspice 44+ supports both; ngspice 43 only supports 0.3. Check your version with `ngspice -v`.
- **Glibc mismatch is likely on older Ubuntu/Debian systems.** The newest builds on that page are compiled against a newer glibc (2.38/2.39-era, roughly Ubuntu 24.04+). On Ubuntu 22.04 (glibc 2.35) the newest builds fail with errors like:
  ```
  openvaf-r: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.39' not found
  ```
  If you hit this, don't try to fix your system glibc, just grab an **older build from the same page**. The plain `openvaf-reloaded-osdi_0.4-linux_x64.tar.gz` (dated 2024-07-07) was built against an older baseline and ran fine on Ubuntu 22.04 in testing.

### Steps that worked

```bash
mkdir -p ~/eda-src/openvaf-r && cd ~/eda-src/openvaf-r
wget https://fides.fe.uni-lj.si/openvaf/download/openvaf-reloaded-osdi_0.4-linux_x64.tar.gz
tar -xzf openvaf-reloaded-osdi_0.4-linux_x64.tar.gz
ls   # confirm the extracted binary's name, e.g. openvaf-r

chmod +x openvaf-r
mkdir -p ~/.local/bin
cp openvaf-r ~/.local/bin/
ln -sf ~/.local/bin/openvaf-r ~/.local/bin/openvaf   # IHP's install.py looks for the name "openvaf"

openvaf-r --version
openvaf --version
```

If both print a version cleanly, you're set to go back and re-run `install.py` from the previous section.

---

## 3. Wiring the tools to each PDK

### xschem

Each PDK ships an `xschemrc` that sets up its symbol/model paths. Launch xschem pointed at the right one:

```bash
xschem --rcfile $PDK_ROOT/sky130A/libs.tech/xschem/xschemrc
xschem --rcfile $PDK_ROOT/ihp-sg13g2/libs.tech/xschem/xschemrc
```

A **shell function that follows your current `$PDK` variable** is convenient when switching between projects as it lets you keep typing the plain `xschem`/`magic` command, and it automatically points at whichever PDK environment you hav set (see below in  `Selecting a PDK environment`). Add to `~/.bashrc`:

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

Invoked automatically by xschem's "simulate" button once the `xschemrc` above is loaded (it sets the right `.spiceinit`/model search paths). For standalone use, `cd` into a directory containing a `.spiceinit` symlinked to the PDK's ngspice setup, or `source` the PDK's model files explicitly in your netlist.

### netgen (LVS)

Netgen setup files live alongside the other tech files:

```bash
netgen -batch lvs "layout.spice layout_top" "schematic.spice schematic_top" \
  $PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl lvs_report.txt
```

Swap in `$PDK_ROOT/ihp-sg13g2/libs.tech/netgen/ihp-sg13g2_setup.tcl` for IHP designs.

(The command above expects real `layout.spice`/`schematic.spice` files to exist see the test version in [Verifying the setup](#verifying-the-setup) if you just want to confirm netgen + the PDK setup file load correctly, without having real netlists yet.)

### Selecting a PDK environment

Rather than typing `PDK`/`PDK_ROOT` every time, `ihp_env_setup` and `sky130_env_setup` can be sourced, which makes switching between a sky130 project and an IHP project painless, since each one just hardcodes its own PDK:

Set a default pdk to use, and add a line to your `.bashrc` file to select that pdk during start-up.

```bash
echo 'source sky130_env_setup' >> .bashrc
source ~/.bashrc
```

If you would like to change to a different pdk just invoke `source ~/FILE/PATH/<pdk-env-file>`
