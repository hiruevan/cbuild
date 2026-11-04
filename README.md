# cbuild

**cbuild** is a Windows PowerShell build helper for C projects targeting the TI-84 Plus CE calculator, Windows desktop, and Linux desktop. It generates the appropriate Makefile or CMake project, compiles the project, and organizes the outputs.

Current source version: **1.6.9**.

| Target | Build environment | Output directory |
|---|---|---|
| TI-84 Plus CE (`-cal`) | CEdev + GNU Make | `bin/cal` |
| Windows desktop (`-win`) | MSYS2 UCRT64 + GCC + CMake + Ninja + SDL2 | `bin/win` |
| Linux x86-64 (`-lnx`) | WSL2 Ubuntu + GCC + CMake + Ninja + SDL2 | `bin/lnx-x86_64` |
| Linux ARM64 (`-lnx aarch64`) | WSL2 Ubuntu + AArch64 cross-compiler + SDL2 | `bin/lnx-aarch64` |
| Linux ARM hard-float (`-lnx armhf`) | WSL2 Ubuntu + ARM hard-float cross-compiler + SDL2 | `bin/lnx-armhf` |

The Windows and Linux desktop builds use `desk_shim`, a compatibility layer that implements selected calculator APIs on desktop. It does not guarantee that every CE-specific API or behavior is supported.

> **Platform note:** cbuild's installer and command-line interface currently run in Windows PowerShell. Linux builds run through WSL2. **macOS is not yet a supported cbuild target.** The CMake template contains an initial Apple bundle branch, but there is not yet a macOS install/build/clean/export workflow. See [macOS support: implementation plan](#macos-support-implementation-plan).

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Project setup](#project-setup)
- [Building](#building)
- [Cleaning](#cleaning)
- [Exporting](#exporting)
- [Linux architectures](#linux-architectures)
- [Sprite utilities](#sprite-utilities)
- [Commands and flags](#commands-and-flags)
- [Output layout](#output-layout)
- [Troubleshooting](#troubleshooting)
- [macOS support: implementation plan](#macos-support-implementation-plan)
- [Uninstalling](#uninstalling)
- [Building and packaging cbuild itself](#building-and-packaging-cbuild-itself)

## Requirements

- Windows 10/11 with Windows PowerShell.
- Internet access to download installer dependencies and target toolchains.
- `winget` for automatic installation of some Windows dependencies.
- Python and `pip`. The base installer attempts to install Python 3.11 if it cannot find Python.
- A C project with a `Project.mk` file for `make`, `clean`, and `export`.

Target-specific requirements:

| Target | Requirements |
|---|---|
| Calculator | CEdev toolchain and GNU Make |
| Windows | MSYS2 UCRT64 GCC, CMake, Ninja, and SDL2 |
| Linux | WSL2 with an Ubuntu distribution, build-essential, CMake, Ninja, and SDL2 development files |
| Linux ARM cross-build | The corresponding cross-compiler and SDL2 development package for the target architecture |

The install commands install most dependencies. Some steps may require administrator approval or a restart.

## Installation

### 1. Get the repository

Clone or download this repository. Open PowerShell in the repository root (the folder containing `package.ps1` and `src`).

### 2. Generate and install cbuild

The repository is split into source files. Run the packaging function to combine the PowerShell modules and embedded resources into a standalone `cbuild.ps1`:

```powershell
. .\package.ps1
Complete-CBuild
```

This generates `cbuild.ps1`, loads it, and runs the base installation. To generate the script without installing it:

```powershell
Complete-CBuild -NoInstall
```

The installed files are placed under your home directory:

```text
$HOME\
└── cbuild\
    ├── cbuild.ps1
    ├── help.txt
    ├── requirements.txt
    ├── desk_shim\
    ├──python\
    └── toolchains\
```

The installer also installs Pillow, registers the cbuild script in your PowerShell profile, and makes the `cbuild` function available in new PowerShell sessions.

If `cbuild.ps1` has already been generated, run it directly:

```powershell
.\cbuild.ps1 install
```

If PowerShell blocks the script, check your execution-policy settings and any organization-managed restrictions. Do not change a managed policy without permission.

### 3. Install the target toolchains

Install only the targets you intend to build:

```powershell
cbuild install -cal
cbuild install -win
cbuild install -lnx
```

Or install every currently supported target environment:

```powershell
cbuild install -all
```

**Important:** `install -all` currently reads `Project.mk` and uses its `PLATFORMS` setting to decide which toolchains to install. Run it from a project directory containing `Project.mk`. If you only want the base cbuild files, use `cbuild install` without `-all`.

The first Linux installation may enable/install WSL2 and Ubuntu 22.04. If prompted, restart Windows and finish Ubuntu's first-run setup (create the Linux user), then run `cbuild install -lnx` again.

For Linux ARM cross-compilation, pass the architecture after `-lnx`:

```powershell
cbuild install -lnx aarch64
cbuild install -lnx armhf
```

You can install both in one command:

```powershell
cbuild install -lnx aarch64 armhf
```

### 4. Verify the installation

Open a new PowerShell session and run:

```powershell
cbuild --version
cbuild -help
```

The current source version is `1.6.9`.

## Project setup

Run `cbuild make`, `cbuild clean`, and `cbuild export` from your C project's root directory. cbuild reads `Project.mk` from the current working directory; it does not search parent directories.

Create a `Project.mk` file:

```makefile
NAME = ExampleGame
DESCRIPTION = Example C game
TARGET = ExampleGame
BIN = bin
BUILD = build
EXPORT = export
SRCDIR = src
INCLUDE = include
RESOURCES = resources
SRC = main.c
PLATFORMS = cal win lnx
```

`NAME` is the only required setting. All other settings are optional:

| Setting | Purpose | Default |
|---|---|---|
| `NAME` | Project name | Required |
| `DESCRIPTION` | Project description | `NAME` |
| `TARGET` | Output target name | `NAME` |
| `BIN` | Compiled output directory | `bin` |
| `BUILD` | Build/intermediate directory | `build` |
| `EXPORT` | Export destination directory | `export` |
| `SRCDIR` | C source directory | `src` |
| `INCLUDE` | Header directory | `include` |
| `RESOURCES` | Resource directory | `resources` |
| `SRC` | Entry-point C source file, relative to `SRCDIR` | `main.c` |
| `PLATFORMS` | Targets selected by `make -all` and `install -all` | `cal win lnx` |

`PLATFORMS` accepts `cal`, `win`, `lnx`, `lnx-x86_64`, `lnx-aarch64`, and `lnx-armhf`. Separate values with spaces, commas, or semicolons. `lnx` selects the default x86-64 Linux target.

Paths are relative to the project root. The configuration parser supports one simple `KEY = VALUE` assignment per line. Blank lines and full-line comments beginning with `#` are ignored; keys are case-insensitive and values may be surrounded by double quotes. This is not a full Makefile parser: variable expansion and general Makefile syntax are not supported.

A basic project layout:

```text
ExampleGame/
├── Project.mk
├── src/
│   ├── main.c
│   └── game.c
├── include/
├── resources/
├── build/       # Generated build files
├── bin/         # Compiled outputs
└── export/      # Optional exported copies
```

The CMake desktop template recursively includes `.c` files under `SRCDIR`. `SRC` identifies the entry-point file and must exist. Keep shared code portable across targets, and isolate platform-specific code behind compile-time checks or separate source files.

## Building

Open PowerShell in the directory containing `Project.mk`.

### Calculator

```powershell
cbuild make -cal
```

cbuild generates a temporary `Makefile`, runs GNU Make with CEdev, then removes the generated Makefile. The resulting calculator program is placed in `bin/cal` and receives the `.8xp` extension.

### Windows desktop

```powershell
cbuild make -win
```

cbuild generates a temporary `CMakeLists.txt`, configures a Ninja build in `build/win`, builds the target, and removes the generated CMake file. The desktop compatibility layer uses SDL2.

### Linux desktop (x86-64)

```powershell
cbuild make -lnx
```

Linux builds run through WSL2. The build directory is `build/lnx-x86_64`; the executable is placed in `bin/lnx-x86_64` with an `.elf` suffix.

### Linux ARM

```powershell
cbuild make -lnx aarch64
cbuild make -lnx armhf
```

Install the matching cross-compiler and SDL2 development package first. The generated binaries must run on a compatible Linux system and CPU architecture.

### Build every configured target

```powershell
cbuild make -all
```

`make -all` uses `PLATFORMS` in `Project.mk`. With the default configuration, it builds calculator, Windows, and Linux x86-64. ARM Linux targets are included only when explicitly listed in `PLATFORMS`.

Build targets individually when diagnosing failures so one target's error does not obscure another.

## Cleaning

Clean a target before rebuilding to remove its CMake cache, object files, generated build files, and binary output:

```powershell
cbuild clean -cal
cbuild clean -win
cbuild clean -lnx
```

Linux clean defaults to x86-64. Specify an architecture to clean a different Linux build:

```powershell
cbuild clean -lnx aarch64
cbuild clean -lnx armhf
```

Clean everything under the configured build and binary directories:

```powershell
cbuild clean -all
```

> **Warning:** `clean -all` recursively deletes the entire directories named by `BUILD` and `BIN` in `Project.mk`, not just cbuild-generated subdirectories. Do not store unrelated files in those directories.

## Exporting

`export` copies built output files from `BIN` into `EXPORT`, preserving their relative subdirectory structure:

```powershell
cbuild export -cal
cbuild export -win
cbuild export -lnx
cbuild export -lnx aarch64
cbuild export -all
```

With the default settings, files are copied into `export/cal`, `export/win`, and `export/lnx-x86_64`, as applicable. The current exporter recognizes `.8xp`, `.8xv`, `.exe`, and `.elf` files. It does not currently package macOS `.app` bundles.

## Linux architectures

| Architecture argument | Output directory | Description |
|---|---|---|
| `x86_64` | `lnx-x86_64` | Standard 64-bit Intel/AMD Linux |
| `aarch64` | `lnx-aarch64` | 64-bit ARM Linux |
| `armhf` | `lnx-armhf` | 32-bit ARM hard-float Linux |

The default is `x86_64`, so `cbuild make -lnx` is equivalent to `cbuild make -lnx x86_64`.

```powershell
cbuild make -lnx aarch64
cbuild make -lnx armhf
cbuild make -lnx aarch64 armhf
```

The corresponding dependencies must be installed first. Cross-compiled binaries are not runnable on the Windows host; run them on a compatible Linux device or emulator.

## Sprite utilities

The installer places the Python helper scripts in `$HOME\python` and installs Pillow. Examples:

```powershell
python "$HOME\python\spritetopngfolder.py" <input_folder> <output_folder> [scale]
python "$HOME\python\createspritefolder.py"
python "$HOME\python\compilespritefolder.py"
python "$HOME\python\generatetileset.py"
```

`spritetopngfolder.py` converts `.sprite` files to PNG files. Its optional scale defaults to `1` and must be at least `1`. The other scripts accept their own arguments; run them without arguments to display their usage.

## Commands and flags

| Command | Purpose |
|---|---|
| `cbuild --version` | Display the installed version |
| `cbuild -help` | Display command help |
| `cbuild install` | Install or repair the base cbuild files |
| `cbuild install -cal` | Install CEdev |
| `cbuild install -win` | Install MSYS2/UCRT64 desktop dependencies |
| `cbuild install -lnx` | Install WSL2/Linux x86-64 dependencies |
| `cbuild install -lnx aarch64` | Install Linux ARM64 cross-build dependencies |
| `cbuild install -lnx armhf` | Install Linux ARM hard-float cross-build dependencies |
| `cbuild install -all` | Install toolchains selected by `PLATFORMS` |
| `cbuild install -force` | Recreate the base cbuild installation |
| `cbuild make -cal` | Build the calculator target |
| `cbuild make -win` | Build the Windows desktop target |
| `cbuild make -lnx [architecture]` | Build a Linux target; defaults to x86-64 |
| `cbuild make -all` | Build targets listed in `PLATFORMS` |
| `cbuild clean -cal` | Clean calculator build/output |
| `cbuild clean -win` | Clean Windows build/output |
| `cbuild clean -lnx [architecture]` | Clean the selected Linux build/output |
| `cbuild clean -all` | Delete the configured `BUILD` and `BIN` directories |
| `cbuild export -cal/-win/-lnx` | Copy selected target files into `EXPORT` |
| `cbuild export -all` | Copy recognized output files from all of `BIN` into `EXPORT` |
| `cbuild uninstall` | Remove cbuild, CEdev, and cbuild-added PATH/profile entries |
| `cbuild uninstall -all` | Also attempt to remove MSYS2 and Linux build packages |
| `cbuild uninstall -force` | Skip the uninstall confirmation prompt |

Linux architecture arguments are positional and must follow `-lnx`. They cannot be combined with `-all`.

## Output layout

With the default `BUILD`, `BIN`, and `EXPORT` settings:

```text
build/
├── cal/
├── win/
├── lnx-x86_64/
├── lnx-aarch64/
└── lnx-armhf/

bin/
├── cal/
├── win/
├── lnx-x86_64/
├── lnx-aarch64/
└── lnx-armhf/

export/
├── cal/
├── win/
└── lnx-x86_64/
```

Only directories for targets that have been built or exported will exist.

## Troubleshooting

### `cbuild` is not recognized

1. Confirm the installer completed successfully.
2. Open a new PowerShell session so your profile is loaded.
3. Inspect the profile:

   ```powershell
   Get-Content $PROFILE
   ```

4. If necessary, load the installed script manually:

   ```powershell
   . "$HOME\cbuild\cbuild.ps1"
   ```

### `Project.mk` not found

Run `make`, `clean`, or `export` from the project root containing `Project.mk`. cbuild does not search parent directories.

### Calculator toolchain not found

Run:

```powershell
cbuild install -cal
```

By default, CEdev is expected at `$HOME\CEdev`. If you installed it elsewhere, set the user `CEDEV` environment variable to the CEdev directory, then open a new PowerShell session.

### Windows build tools are missing

Run:

```powershell
cbuild install -win
```

The installer expects MSYS2 at `C:\msys64` and uses its UCRT64 toolchain. Confirm `C:\msys64\ucrt64\bin` is on PATH, then reopen PowerShell.

### WSL or Ubuntu is not ready

Check WSL:

```powershell
wsl --status
wsl -l -q
```

Finish Ubuntu's first-run setup if necessary, then run `cbuild install -lnx` again.

### ARM Linux compiler is missing

Install the matching architecture:

```powershell
cbuild install -lnx aarch64
# or
cbuild install -lnx armhf
```

### Python sprite tools fail

Check Python and Pillow:

```powershell
python --version
python -m pip show pillow
```

If Pillow is missing:

```powershell
python -m pip install pillow
```

### Build configuration appears stale

Clean and rebuild the affected target:

```powershell
cbuild clean -win
cbuild make -win
```

Use the corresponding target and architecture flags for other builds.

## macOS support: implementation plan

macOS is **not implemented as a cbuild target yet**. There is an `APPLE` branch in `toolchains/toolchain-desk.cmake`, but the current command dispatcher, dependency installer, build/clean routines, and exporter do not expose a `mac` target.

A proper implementation should add these pieces:

1. **Choose the build host.** A native macOS build requires macOS, Xcode Command Line Tools (Clang, SDK, and Apple frameworks), CMake, and Ninja. A Windows PC cannot produce a supported macOS app simply by using WSL. If you want builds triggered from Windows, cbuild will need to call a remote Mac (for example, a self-hosted Mac runner or CI service).
2. **Add the `mac` platform to command parsing.** Support `cbuild install -mac`, `make -mac`, `clean -mac`, `export -mac`, and `-mac` in `PLATFORMS`.
3. **Add native macOS dependency checks.** Verify `xcode-select`, `cmake`, and `ninja`; do not try to install Apple's SDK from Windows.
4. **Build with the existing CMake Apple branch.** Generate `CMakeLists.txt`, configure a `build/mac` directory on macOS, and build a `.app` bundle into `bin/mac`.
5. **Fix bundle metadata and resources.** Use a valid reverse-DNS bundle identifier, set version values from project configuration, and ensure icons/resources are copied into the bundle correctly.
6. **Update clean and export.** Cleaning must remove `build/mac` and `bin/mac`; exporting must copy `.app` directories as bundles rather than filtering only files by extension.
7. **Test on real macOS.** Test both Apple Silicon (`arm64`) and Intel (`x86_64`) if both are intended, plus SDL2 linking and runtime resource paths.

The first implementation milestone should be a **native macOS build on a Mac**. Once that works, decide whether to add remote builds initiated from Windows. This avoids conflating macOS compilation with Linux cross-compilation.

## Uninstalling

Run:

```powershell
cbuild uninstall
```

The command asks for confirmation, then removes cbuild, CEdev, cbuild-added PATH entries, and the cbuild line from your PowerShell profile.

To also attempt to uninstall MSYS2 and remove Linux build packages:

```powershell
cbuild uninstall -all
```

Skip the confirmation prompt with:

```powershell
cbuild uninstall -force
```

> **Caution:** `uninstall -all` removes the MSYS2 installation directory and attempts to remove build packages from WSL. It does not uninstall the WSL distribution itself.

## Building and packaging cbuild itself

The repository stores its implementation in `src` and keeps templates and helper resources in separate folders. `package.ps1` combines the source scripts and replaces placeholders such as `<requirements.txt>` and `<toolchains/toolchain-desk.cmake>` with their file contents.

From the repository root:

```powershell
. .\package.ps1
Complete-CBuild
```

To only generate the standalone script:

```powershell
Complete-CBuild -NoInstall
```

If you change files under `src`, `toolchains`, `desk_shim`, `python`, `requirements.txt`, or `help.txt`, regenerate `cbuild.ps1` so the packaged installer includes those changes.
