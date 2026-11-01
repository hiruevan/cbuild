# cbuild

**cbuild** is a Windows PowerShell build helper for C projects. It provides a single command to build TI-84 Plus CE calculator programs and desktop builds for Windows and Linux, including optional Linux cross-compilation for ARM targets.

| Target | Build system / toolchain | Output target directory |
|---|---|---|
| TI-84 Plus CE (`-cal`) | CEdev and GNU Make | `cal` |
| Windows (`-win`) | MSYS2 UCRT64, GCC, CMake, Ninja, SDL2 | `win` |
| Linux x86-64 (`-lnx`) | WSL2, Ubuntu, GCC, CMake, Ninja, SDL2 | `lnx-x86_64` |
| Linux ARM64 (`-lnx aarch64`) | WSL2, Ubuntu, AArch64 cross-compiler | `lnx-aarch64` |
| Linux ARM hard-float (`-lnx armhf`) | WSL2, Ubuntu, ARM hard-float cross-compiler | `lnx-armhf` |

The Windows and Linux desktop builds use the included `port_shim` to implement selected calculator APIs on desktop. It is a compatibility layer, not a guarantee that every CE-specific API or behavior is available.

> **Platform:** Installation and the `cbuild` command run in Windows PowerShell. Linux builds are performed through WSL2.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Project setup](#project-setup)
- [Building](#building)
- [Cleaning](#cleaning)
- [Linux architectures](#linux-architectures)
- [Sprite utilities](#sprite-utilities)
- [Commands and flags](#commands-and-flags)
- [Output layout](#output-layout)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)
- [Building and packaging cbuild itself](#building-and-packaging-cbuild-itself)

## Requirements

- Windows 10/11 with Windows PowerShell.
- Internet access to download the installer dependencies and target toolchains.
- `winget` for automatic installation of some Windows dependencies.
- Python and `pip`. The base installer attempts to install Python 3.11 if `python` is unavailable.
- A C project with a `Project.mk` file for `make` and `clean`.

Target-specific requirements:

| Target | Requirements |
|---|---|
| Calculator | CEdev toolchain |
| Windows | MSYS2 with UCRT64 GCC, CMake, Ninja, and SDL2 |
| Linux | WSL2 with an Ubuntu distribution, build-essential, CMake, Ninja, and SDL2 development files |
| Linux ARM cross-build | The corresponding cross-compiler and SDL2 development package for the target architecture |

The install commands can install most of these dependencies. Some steps may require administrator approval or a restart.

## Installation

### 1. Get the project

Clone or download this repository. Open PowerShell in the repository's root directory (the directory containing `package.ps1` and `src`).

### 2. Generate and install the cbuild command

The repository is split into source files. Run the packaging function to combine the scripts and embedded resources into a standalone `cbuild.ps1`:

```powershell
. .\package.ps1
complete-cbuild
```

This creates `cbuild.ps1` in the repository root and runs its base installation.

The installer places the installed command and shared files under:

```text
$HOME\
├── cbuild\
│   ├── cbuild.ps1
│   ├── makefiles\
│   └── port_shim\
└── python\
    ├── compilespritefolder.py
    ├── createspritefolder.py
    ├── generatetileset.py
    └── spritetopngfolder.py
```

It also installs Pillow, creates or updates your PowerShell profile so it dot-sources the installed script, and makes the `cbuild` function available in new PowerShell sessions.

If you already generated `cbuild.ps1`, you can run it directly:

```powershell
.\cbuild.ps1 install
```

If PowerShell blocks the script, check your execution-policy settings and any organization-managed restrictions. Do not change a managed policy without permission.

### 3. Install the target dependencies

Install only the toolchains you plan to use:

```powershell
cbuild install -cal
cbuild install -win
cbuild install -lnx
```

Or install all three target environments:

```powershell
cbuild install -all
```

For Linux, the first installation may enable/install WSL2 and Ubuntu 22.04. If prompted, restart Windows and finish Ubuntu's first-run setup (create the Linux user). Then run `cbuild install -lnx` again.

For ARM Linux cross-compilation, specify the architecture after `-lnx`:

```powershell
cbuild install -lnx aarch64
cbuild install -lnx armhf
```

The default Linux install (`cbuild install -lnx`) installs the standard x86-64 build dependencies. You can install multiple architecture names in one invocation:

```powershell
cbuild install -lnx aarch64 armhf
```

### 4. Verify

Open a new PowerShell session, then run:

```powershell
cbuild --version
cbuild -help
```

The version reported by this source is **1.2.14**.

## Project setup

Run `cbuild make` and `cbuild clean` from your C project's root directory. cbuild reads `Project.mk` from the current working directory; it does not search parent directories.

Create a `Project.mk` file:

```makefile
NAME = ExampleGame
DESCRIPTION = Example C game
TARGET = ExampleGame
BIN = bin
BUILD = build
SRCDIR = src
INCLUDE = include
RESOURCES = resources
SRC = main.c
```

`NAME` is the only required setting. The other settings are optional and default as follows:

| Setting | Purpose | Default |
|---|---|---|
| `NAME` | Project name | Required |
| `DESCRIPTION` | Project description | `NAME` |
| `TARGET` | Executable / output target name | `NAME` |
| `BIN` | Compiled output directory | `bin` |
| `BUILD` | Generated build files and intermediate files | `build` |
| `SRCDIR` | C source directory | `src` |
| `INCLUDE` | Header directory | `include` |
| `RESOURCES` | Resource directory | `resources` |
| `SRC` | Source file(s) passed to the build template | `main.c` |

Paths are relative to the project root. The configuration parser expects one simple `KEY = VALUE` assignment per line. Blank lines and full-line comments beginning with `#` are ignored. Keys are case-insensitive; values may optionally be surrounded by double quotes. The parser does not implement full Makefile syntax or variable expansion.

A basic project could look like this:

```text
ExampleGame/
├── Project.mk
├── src/
│   └── main.c
├── include/
├── resources/
├── build/       # Generated build files
└── bin/         # Compiled output
```

The exact source files and folders depend on your project and the build template.

## Building

Open PowerShell in the directory containing `Project.mk`.

### Calculator

```powershell
cbuild make -cal
```

cbuild generates a temporary `Makefile` from the calculator template, runs `make`, and removes the generated file afterward.

### Windows desktop

```powershell
cbuild make -win
```

cbuild generates a temporary `CMakeLists.txt`, configures a Ninja build in `build\win`, builds the target, and removes the generated CMake file.

### Linux desktop (x86-64)

```powershell
cbuild make -lnx
```

Linux builds run through WSL2. The build directory is `build/lnx-x86_64`.

### Build every target

```powershell
cbuild make -all
```

Or build targets individually to make failures easier to isolate:

```powershell
cbuild make -cal
cbuild make -win
cbuild make -lnx
```

## Cleaning

Clean one target before rebuilding if you need to remove stale CMake configuration, object files, or output:

```powershell
cbuild clean -cal
cbuild clean -win
cbuild clean -lnx
```

Linux clean defaults to the x86-64 target. To clean a specific Linux architecture, provide its name:

```powershell
cbuild clean -lnx aarch64
cbuild clean -lnx armhf
```

Clean all configured build and binary output directories:

```powershell
cbuild clean -all
```

> **Warning:** `clean -all` recursively deletes the entire directories named by `BUILD` and `BIN` in `Project.mk`, not just cbuild-generated target subdirectories. Do not store unrelated files in those directories.

## Linux architectures

The supported Linux architecture names are:

| Architecture argument | Target directory | Description |
|---|---|---|
| `x86_64` | `lnx-x86_64` | Standard 64-bit Intel/AMD Linux |
| `aarch64` | `lnx-aarch64` | 64-bit ARM Linux (for example, Raspberry Pi OS 64-bit) |
| `armhf` | `lnx-armhf` | 32-bit ARM hard-float Linux |

The default architecture is `x86_64`, so this is equivalent to `cbuild make -lnx x86_64`:

```powershell
cbuild make -lnx
```

Build an ARM target by passing its architecture after `-lnx`:

```powershell
cbuild make -lnx aarch64
cbuild make -lnx armhf
```

You can request more than one Linux architecture in the same command:

```powershell
cbuild make -lnx aarch64 armhf
```

Install the matching cross-compilation dependencies first with `cbuild install -lnx aarch64` or `cbuild install -lnx armhf`. The generated binaries are cross-compiled; they must be run on a compatible machine or device and operating-system environment.

## Sprite utilities

The installer places the Python helper scripts in `$HOME\python` and installs Pillow. Invoke them with Python:

```powershell
python "$HOME\python\spritetopngfolder.py" <input_folder> <output_folder> [scale]
python "$HOME\python\createspritefolder.py"
python "$HOME\python\compilespritefolder.py"
python "$HOME\python\generatetileset.py"
```

`spritetopngfolder.py` converts `.sprite` files in an input folder to PNG files in an output folder. Its optional `scale` argument defaults to `1` and must be at least `1`. The other scripts accept their own arguments; run them without arguments to see their usage instructions.

## Commands and flags

| Command | Purpose |
|---|---|
| `cbuild --version` | Display the installed version |
| `cbuild -help` / `cbuild --help` | Display command help |
| `cbuild install` | Install or repair the base cbuild files |
| `cbuild install -cal` | Install calculator dependencies |
| `cbuild install -win` | Install Windows dependencies |
| `cbuild install -lnx` | Install standard Linux x86-64 dependencies |
| `cbuild install -lnx aarch64` | Install Linux ARM64 cross-build dependencies |
| `cbuild install -lnx armhf` | Install Linux ARM hard-float cross-build dependencies |
| `cbuild install -all` | Install all target dependencies |
| `cbuild install -force` | Force recreation of the base cbuild installation |
| `cbuild make -cal` | Build the calculator target |
| `cbuild make -win` | Build the Windows target |
| `cbuild make -lnx [architecture]` | Build the selected Linux architecture (defaults to `x86_64`) |
| `cbuild make -all` | Build calculator, Windows, and default Linux targets |
| `cbuild clean -cal` | Remove calculator build and binary output folders |
| `cbuild clean -win` | Remove Windows build and binary output folders |
| `cbuild clean -lnx [architecture]` | Remove the selected Linux build and binary output folders |
| `cbuild clean -all` | Remove the configured `BUILD` and `BIN` directories |
| `cbuild uninstall` | Remove cbuild, CEdev, and cbuild-added PATH/profile entries |
| `cbuild uninstall -all` | Also attempt to remove MSYS2 and Linux build packages |
| `cbuild uninstall -force` | Skip the uninstall confirmation prompt |

`-force` on `install` forces the base installation to be recreated; it does not guarantee every existing target dependency is reinstalled.

Linux architecture arguments are positional and must follow `-lnx`. They are supported only with `-lnx`, not with `-all`.

## Output layout

With the default `BUILD` and `BIN` settings, the generated layout is:

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
```

Only directories for targets you have built will exist. The actual top-level directory names follow the `BUILD` and `BIN` settings in `Project.mk`.

## Troubleshooting

### `cbuild` is not recognized

1. Confirm that `complete-cbuild` or the standalone installer completed successfully.
2. Open a new PowerShell session so your profile is loaded.
3. Run `Get-Content $PROFILE` and confirm it dot-sources `$HOME\cbuild\cbuild.ps1`.
4. If needed, load it manually:

   ```powershell
   . "$HOME\cbuild\cbuild.ps1"
   ```

### `Project.mk` not found

Run the command from the project root, where `Project.mk` is located. cbuild does not search parent directories.

### `make` or a compiler is not found for the calculator build

Run:

```powershell
cbuild install -cal
```

Confirm CEdev is installed under `$HOME\CEdev` (unless your `CEDEV` environment variable points elsewhere), then open a new PowerShell session and retry.

### Windows build tools are missing

Run:

```powershell
cbuild install -win
```

The installer uses MSYS2 at `C:\msys64` and its UCRT64 toolchain. Confirm `C:\msys64\ucrt64\bin` is on your user PATH, then reopen PowerShell.

### WSL or Ubuntu is not ready

Check WSL and installed distributions:

```powershell
wsl --status
wsl -l -q
```

Finish Ubuntu's first-run setup if it has not been completed, then run `cbuild install -lnx` again.

### ARM Linux build reports a missing cross-compiler

Install the matching architecture dependencies:

```powershell
cbuild install -lnx aarch64
# or
cbuild install -lnx armhf
```

Then retry the build. The build command checks that the requested cross-compiler is installed.

### Build configuration appears stale

Clean the affected target and rebuild:

```powershell
cbuild clean -win
cbuild make -win
```

Use the corresponding target and architecture flags for other builds. Remember that clean removes the selected target's build and binary directories.

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

## Uninstalling

Run:

```powershell
cbuild uninstall
```

The command asks for confirmation, then removes cbuild, the CEdev calculator toolchain, cbuild-added PATH entries, and the cbuild line from your PowerShell profile.

To also attempt to uninstall MSYS2 and remove the Linux build packages:

```powershell
cbuild uninstall -all
```

Skip the confirmation prompt with:

```powershell
cbuild uninstall -force
```

> **Caution:** `uninstall -all` removes the MSYS2 installation directory and attempts to remove build packages and cross-compilation packages from WSL. Review the confirmation prompt before proceeding. It does not uninstall the WSL distribution itself.

## Building and packaging cbuild itself

The repository keeps the PowerShell implementation in `src` and stores build templates and helper resources alongside it. `package.ps1` combines the source scripts and replaces resource placeholders such as `<requirements.txt>` and `<makefiles/CMakeLists.txt>` with the contents of the referenced files.

From the repository root:

```powershell
. .\package.ps1
complete-cbuild
```

This writes the combined `cbuild.ps1`, reloads it, and invokes `cbuild install -force`.

The generated `cbuild.ps1` is the standalone installer entry point. If you change files under `src`, `makefiles`, `port_shim`, `python`, `requirements.txt`, or `help.txt`, regenerate the script so the packaged copy includes those changes.
