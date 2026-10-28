# cbuild

**cbuild** is a PowerShell build helper for C projects targeting TI-84 Plus CE calculators, Windows, and Linux. It installs the toolchains and shared build files, reads project settings from `Project.mk`, and generates the build-system files needed for the selected target.

- **Calculator:** CE toolchain / CEdev and Make
- **Windows:** MSYS2, GCC, CMake, Ninja, and SDL2
- **Linux:** WSL2 with Ubuntu, GCC/build tools, CMake, Ninja, and SDL2
- **Utilities:** Python sprite helpers, including conversion between `.sprite` files and PNGs

> **Platform:** The installer and `cbuild` command are designed for Windows PowerShell. The Linux target is built through WSL2.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Project setup](#project-setup)
- [Usage](#usage)
- [Commands and flags](#commands-and-flags)
- [Output directories](#output-directories)
- [Troubleshooting](#troubleshooting)
- [Uninstalling](#uninstalling)

## Requirements

- Windows with PowerShell
- Internet access during installation to download toolchains and packages
- `winget` for automatic installation of some dependencies
- Python 3.11 or another working `python` command; the installer attempts to install Python 3.11 if it cannot find Python
- A project with a `Project.mk` file for `make` and `clean`

Optional target-specific requirements:

| Target | Dependencies installed by cbuild |
|---|---|
| TI-84 Plus CE calculator (`-cal`) | CEdev calculator toolchain |
| Windows desktop (`-win`) | MSYS2, UCRT64 GCC, CMake, Ninja, SDL2 |
| Linux desktop (`-lnx`) | WSL2 and Ubuntu, then `build-essential`, CMake, Ninja, SDL2 development libraries |

The Windows and Linux desktop targets use the project's portability shim to provide desktop implementations of selected calculator APIs. This does not guarantee every calculator-specific API or behavior is supported on desktop.

## Installation

### 1. Save the installer script

Download or clone the `cbuild.ps1` script and open PowerShell in the directory containing it.

### 2. Install cbuild

Install the base tool and shared files:

```powershell
.\cbuild.ps1 install
```

The installer copies cbuild to:

```text
$HOME\cbuild\cbuild.ps1
```

It also creates the shared `port_shim`, build templates, and Python helper scripts, installs Pillow for sprite utilities, and adds a dot-source line to your PowerShell profile so the `cbuild` function is available in future sessions.

If PowerShell blocks the script because of its execution policy, review your organization's policy and your PowerShell execution-policy settings before changing them. Do not weaken a managed policy without permission.

### 3. Install the target toolchains

Choose the targets you intend to build:

```powershell
# Calculator toolchain
cbuild install -cal

# Windows desktop toolchain
cbuild install -win

# Linux desktop toolchain through WSL2
cbuild install -lnx

# All target toolchains
cbuild install -all
```

You can also install only the base cbuild files with `cbuild install`.

For Linux, if WSL2/Ubuntu is not installed, cbuild attempts to install Ubuntu. Follow any Windows prompts, restart if required, complete Ubuntu's first-run setup, then run:

```powershell
cbuild install -lnx
```

The installer may require administrator approval for Windows features or software installation. Close and reopen PowerShell after installation if updated PATH entries or profile changes are not visible.

### 4. Verify the installation

```powershell
cbuild --version
cbuild -help
```

The version shown by the supplied script is `1.2.9`.

## Project setup

Run `cbuild make` and `cbuild clean` **from the root of your project**, where `Project.mk` is located. cbuild reads this file from the current working directory.

Create a `Project.mk` file with at least a `NAME` setting. For example:

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

`NAME` is required. All other settings are optional and use the defaults shown above when omitted or left empty.

| Setting | Meaning | Default |
|---|---|---|
| `NAME` | Project name | Required |
| `DESCRIPTION` | Project description | `NAME` |
| `TARGET` | Build target name | `NAME` |
| `BIN` | Output directory | `bin` |
| `BUILD` | Build directory | `build` |
| `SRCDIR` | Source directory | `src` |
| `INCLUDE` | Include directory | `include` |
| `RESOURCES` | Resource directory | `resources` |
| `SRC` | Source file(s) supplied to the build template | `main.c` |

Paths are relative to the project root. Use simple `KEY = VALUE` lines; the parser expects one assignment per line and skips blank lines and full-line comments beginning with `#`.

A typical project layout might look like this:

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

Adjust the layout and `Project.mk` values to match your actual project. The example is illustrative; the source files and required directories depend on your build template and code.

## Usage

Open PowerShell and change to the project root:

```powershell
cd C:\path\to\ExampleGame
```

### Build for a TI-84 Plus CE calculator

```powershell
cbuild make -cal
```

This generates a temporary `Makefile` from cbuild's calculator template, invokes `make`, and removes the generated `Makefile` afterward.

### Build for Windows

```powershell
cbuild make -win
```

This generates a temporary `CMakeLists.txt`, configures a Ninja build under `build\win` (or your configured build directory), and compiles the Windows target. The generated `CMakeLists.txt` is removed after the build.

### Build for Linux

```powershell
cbuild make -lnx
```

This invokes CMake and Ninja through WSL2. Make sure WSL2 and the Linux dependencies are installed first. The Linux build directory is `build/lnx` (or your configured build directory).

### Build multiple targets

Run each target explicitly:

```powershell
cbuild make -cal
cbuild make -win
cbuild make -lnx
```

The `make` command accepts `-cal`, `-win`, and `-lnx`. Although the help text mentions `-all`, the implementation's target selection treats it as all three targets; use separate commands if you prefer to build and diagnose targets independently.

### Clean build outputs

If a build fails due to stale generated files or configuration, clean the affected target and build again:

```powershell
cbuild clean -cal
cbuild clean -win
cbuild clean -lnx
```

Remove all three targets' build and binary output directories with:

```powershell
cbuild clean -all
```

**Warning:** `clean -all` deletes the configured build and binary directories for all three targets. Back up anything important stored in those directories first.

### Python sprite utilities

The installer places helper scripts in `$HOME\python` and installs Pillow. Run the scripts with Python, supplying the arguments shown by each script:

```powershell
# Convert all .sprite files in an input folder to PNGs.
python "$HOME\python\spritetopngfolder.py" <input_folder> <output_folder> [scale]

# Other helpers (check the script's usage output for exact arguments).
python "$HOME\python\createspritefolder.py"
python "$HOME\python\compilespritefolder.py"
python "$HOME\python\generatetileset.py"
```

For `spritetopngfolder.py`, `scale` is optional and defaults to `1`; it must be at least `1`. Replace the angle-bracket placeholders with real paths. The other utilities have their own argument requirements, so consult their usage messages before running them.

## Commands and flags

| Command | Purpose |
|---|---|
| `cbuild -help` or `cbuild --help` | Display built-in help |
| `cbuild --version` | Show the cbuild version |
| `cbuild install` | Install cbuild's shared files and helpers |
| `cbuild install -cal` | Install calculator dependencies |
| `cbuild install -win` | Install Windows dependencies |
| `cbuild install -lnx` | Install Linux/WSL dependencies |
| `cbuild install -all` | Install all target dependencies |
| `cbuild install -force` | Force the base installation to be recreated |
| `cbuild make -cal` | Build calculator target |
| `cbuild make -win` | Build Windows target |
| `cbuild make -lnx` | Build Linux target through WSL2 |
| `cbuild clean -cal` | Delete calculator build and binary output directories |
| `cbuild clean -win` | Delete Windows build and binary output directories |
| `cbuild clean -lnx` | Delete Linux build and binary output directories |
| `cbuild clean -all` | Delete build and binary output directories for all targets |
| `cbuild uninstall` | Remove cbuild, CEdev, and cbuild-added PATH/profile entries |
| `cbuild uninstall -all` | Also attempt to uninstall MSYS2 and remove Linux build packages |
| `cbuild uninstall -force` | Skip the uninstall confirmation prompt |

`-force` on `install` applies to the base cbuild installation. It does not mean every target dependency will necessarily be downloaded again if the target toolchain is already present.

## Output directories

With the default configuration:

```text
build/
├── cal/
├── win/
└── lnx/

bin/
├── cal/
├── win/
└── lnx/
```

The actual directory names follow your `BUILD` and `BIN` settings. `clean` removes the selected target's matching directories; it does not merely remove intermediate object files.

## Troubleshooting

### `cbuild` is not recognized

1. Confirm the base install completed.
2. Close and reopen PowerShell so the profile is reloaded.
3. Run `cbuild -help`.
4. If necessary, inspect your PowerShell profile (`$PROFILE`) and verify it dot-sources `$HOME\cbuild\cbuild.ps1`.

### `Project.mk` is missing

Run `cbuild make` or `cbuild clean` from the directory containing `Project.mk`. These commands do not search parent directories for the file.

### A build fails or generated configuration seems stale

Run the matching clean command, then retry:

```powershell
cbuild clean -win
cbuild make -win
```

Replace `-win` with `-cal` or `-lnx` as needed. Cleaning deletes that target's build and binary output directories.

### Windows compiler or SDL2 tools are not found

Run `cbuild install -win`, then reopen PowerShell. Confirm that MSYS2 is installed at `C:\msys64` and that its `ucrt64\bin` directory is on PATH.

### Linux build fails

1. Confirm `wsl.exe` is available.
2. Run `wsl -l -q` to check that a Linux distribution is installed.
3. Complete Ubuntu's first-run setup if needed.
4. Run `cbuild install -lnx` again.
5. Try `cbuild clean -lnx`, followed by `cbuild make -lnx`.

### Calculator build fails

Run `cbuild install -cal` and confirm that the CEdev toolchain is installed under `$HOME\CEdev`. Then run `cbuild clean -cal` and retry the build.

### Sprite helpers fail

Confirm Python is available:

```powershell
python --version
python -m pip show pillow
```

If Pillow is missing, install it with:

```powershell
python -m pip install pillow
```

### A command or flag is rejected

Use `cbuild -help`. Commands and flags are validated by cbuild; unsupported flags will produce an error.

## Uninstalling

Run:

```powershell
cbuild uninstall
```

The command asks for confirmation, then removes cbuild, the CEdev calculator toolchain, cbuild-added PATH entries, and its PowerShell profile entry. It does **not** uninstall MSYS2 or remove the Linux packages unless you use `-all`.

To request a full uninstall:

```powershell
cbuild uninstall -all
```

To skip the confirmation prompt:

```powershell
cbuild uninstall -force
```

**Caution:** `uninstall -all` can remove MSYS2 and attempts to remove the listed Linux build packages from WSL. Review the prompt and your environment before proceeding.

---