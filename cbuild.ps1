$script:CBuildInstallDir = Join-Path $HOME "cbuild"
$script:CBuildPortShimDir = Join-Path $script:CBuildInstallDir "port_shim"
$script:CBuildCalcShimDir = Join-Path $script:CBuildInstallDir "calc_shim"
$script:CBuildMakefileDir = Join-Path $script:CBuildInstallDir "makefiles"
$script:CBuildHelperDir = Join-Path $HOME "python"

$script:CbiuldVersion = "1.2.9"


function cbuild {
    $cbuildArgs = @($args | ForEach-Object { [string]$_ })

    # Install flag
    $requirementsDir = Join-Path $script:CBuildInstallDir "requirements.txt"
    $isInstalled = Test-Path -Path $requirementsDir

    # Help
    if ($cbuildArgs -contains "-help" -or
        $cbuildArgs -contains "--help") {

        Write-Host @"
cbuild - C For Calculator and other Platforms Build Helper

Usage:
  cbuild -help
  cbuild --version
  cbuild install [-cal] [-win] [-lnx] [-all]
  cbuild uninstall [-all] [-force]
  cbuild clean [-cal] [-win] [-lnx] [-all]
  cbuild make  [-cal] [-win] [-lnx]

Commands:
  uninstall Deletes all dependencies and removes cbuild
  install   Installs cbuild dependancies
  clean     Configure or clean build targets
  make      Build selected targets

Install flags:
  -cal      ...
  -win      ...
  -lnx      Installs relevant dependencies for calculator, windows and linux
  -all      Installs all dependencies
  -force    Reinstalls cbuild even if it is already installed

Uninstall flags:
  -all      Also uninstalls MSYS2 and the WSL build packages
  -force    Skips the confirmation prompt

Clean flags:
  -cal      Cleans calculator obj
  -win      Cleans Windows obj and prepares for build
  -lnx      Cleans Linux obj and prepares for build
  -all      Cleans all the builds, delete obj and bin

Make flags:
  -cal      Compiles and builds for calculator
  -win      Builds for Windows
  -lnx      Builds for Linux through WSL2

NOTE: If you encounter an error with the MAKE command, run CLEAN first.
"@
        return
    }

    # Version
    if ($cbuildArgs -contains "--version" -or $cbuildArgs.Count -eq 0) {
        if (-not $isInstalled) {
            Write-Output "cbuild is not installed. Run 'cbuild install' to install it."
            return
        }
        Write-Output "cbuild version " $Script:CbiuldVersion
        return
    }

    $action = $cbuildArgs[0].ToLowerInvariant()
    $flags = @($cbuildArgs | Select-Object -Skip 1)

    # Validate command
    if ($action -notin @("clean", "make", "install", "uninstall")) {
        Write-Error "Unknown command '$action'. Run 'cbuild -help'."
        return
    }

    # Validate flags
    $allowedFlags = switch ($action) {
        "install" { @("-win", "-cal", "-lnx", "-all", "-force") }
        "uninstall" { @("-all", "-force") }
        "clean"   { @("-win", "-cal", "-lnx", "-all") }
        "make"    { @("-win", "-cal", "-lnx", "-all") }
    }

    foreach ($flag in $flags) {
        if ($flag -notin $allowedFlags) {
            Write-Error "Unknown flag '$flag' for '$action'. Run 'cbuild -help'."
            return
        }
    }

    if ($flags.Count -eq 0 -and -not ($action -eq "install" -or $action -eq "uninstall")) {
        Write-Error "Specify at least one flag. Run 'cbuild -help'."
        return
    }

    # Determine targets
    $forceRun = $flags -contains "-force"
    $runAll = $flags -contains "-all"
    $runCal = $flags -contains "-cal" -or $runAll
    $runWin = $flags -contains "-win" -or $runAll
    $runLnx = $flags -contains "-lnx" -or $runAll

    # === UNINSTALL command ===
    # delete cbuild directory
    if ($action -eq "uninstall") {
        Uninstall-CBuild -Full $runAll -Force $forceRun
        return
    }

    # === INSTALL command ===
    # Install basic cbuild profile
    if ($action -eq "install") {
        # Install cbuild files
        Install-cbuild -force $forceRun
    }

    # Install calculator profile
    if ($action -eq "install" -and $runCal) {
        Install-cbuildCalculator
    }

    # Install windows profile
    if ($action -eq "install" -and $runWin) {
        Install-cbuildWindows
    }

    # Install linux profile
    if ($action -eq "install" -and $runLnx) {
        Install-cbuildLinux
    }

    if ($action -eq "install") {
        Write-Host "`ncbuild installed successfully." -ForegroundColor Green
        return
    }

    # Install prompt
    if (-not $isInstalled) {
        Write-Output "cbuild is not installed. Run 'cbuild install' to install it."
        return
    }

    # === MAKE and CLEAN commands ===
    # Get build config
    if ($action -in @("make", "clean")) {
        $cfg = Read-CBuildConfig
    }

    # Helper: remove a directory if it exists.
    $removeFolder = {
        param([string]$Path)

        if (Test-Path -LiteralPath $Path) {
            Write-Host "Deleting $Path"
            Remove-Item -LiteralPath $Path -Recurse -Force `
                -ErrorAction Stop
        }
    }

    # --- CLEAN TARGETS ---
    # Clean all: remove output directories first
    if (($action -eq "clean" -and $runAll)) {
        Write-Host "`n>>> Cleaning all current builds..."
    }

    # Clean calculator
    if ($action -eq "clean" -and $runCal) {
        Write-Host "`n>>> Cleaning calculator build..."
        & $removeFolder "$($cfg.BUILD)/cal"
        & $removeFolder "$($cfg.BIN)/cal"
    }

    # Clean windows
    if ($action -eq "clean" -and $runWin) {
        Write-Host "`n>>> Cleaning Windows build..."
        & $removeFolder "$($cfg.BUILD)/win"
        & $removeFolder "$($cfg.BIN)/win"
    }

    # Clean linux
    if ($action -eq "clean" -and $runLnx) {
        Write-Host "`n>>> Cleaning Linux build..."
        & $removeFolder "$($cfg.BUILD)/lnx"
        & $removeFolder "$($cfg.BIN)/lnx"
    }

    # --- MAKE TARGETS ---
    # Build calculator
    if ($action -eq "make" -and $runCal) {
        Write-Host "`n>>> Configuring calculator build..."
        New-CBuildFile (Join-Path $script:CBuildMakefileDir "CEMakefile.mk") "Makefile" $cfg

        Write-Host "`n>>> Building calculator target..."
        & make

        # Clean up
        Remove-Item -Path (Join-Path $PWD.Path "Makefile") -Force

        if ($LASTEXITCODE -ne 0) {
            throw "Calculator build failed with exit code $LASTEXITCODE."
        }
    }

    # Build windows
    if ($action -eq "make" -and $runWin) {
        Write-Host "`n>>> Configuring Windows build..."
        
        New-CBuildFile (Join-Path $script:CBuildMakefileDir "CMakeLists.txt") "CMakeLists.txt" $cfg
        $buildDir = Join-Path (Join-Path $PWD $cfg.BUILD) "win"

        & cmake -S . -B $buildDir -G Ninja `
            -DCMAKE_BUILD_TYPE=Release

        Write-Host "`n>>> Building Windows target..."
        & cmake --build $buildDir

        # Clean up
        Remove-Item -Path (Join-Path $PWD.Path "CMakeLists.txt") -Force

        if ($LASTEXITCODE -ne 0) {
            throw "Windows build failed with exit code $LASTEXITCODE."
        }
    }

    # Build linux
    if ($action -eq "make" -and $runLnx) {
        Write-Host "`n>>> Configuring Linux build..."

        $winShim  = Join-Path $HOME "cbuild/port_shim"
        $linuxShim = (& wsl.exe wslpath -a ($winShim.Replace('\', '/'))).Trim()

        New-CBuildFile (Join-Path $script:CBuildMakefileDir "CMakeLists.txt") "CMakeLists.txt" $cfg -Shim $linuxShim
        $buildDir = $cfg.BUILD + "/lnx"

        & wsl.exe --cd "$($PWD.Path)" cmake -S . -B $buildDIr -G Ninja -DCMAKE_BUILD_TYPE=Release

        Write-Host "`n>>> Building Linux target through WSL2..."
        & wsl.exe --cd "$($PWD.Path)" cmake --build $buildDIr --parallel

        # Clean up
        Remove-Item -Path (Join-Path $PWD.Path "CMakeLists.txt") -Force

        if ($LASTEXITCODE -ne 0) {
            throw "Linux build failed: exit code $LASTEXITCODE."
        }
    }

    Write-Host "`ncbuild completed successfully." -ForegroundColor Green
    return
}


# === Read Build Config Helper Functions ===
function Read-CBuildConfig {
    param([string]$Path = (Join-Path $PWD.Path "Project.mk"))

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No Project.mk found in $($PWD.Path)."
    }

    $cfg = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -match '^\s*([A-Za-z_]\w*)\s*=\s*"?(.*?)"?\s*$') {
            $cfg[$matches[1].ToUpperInvariant()] = $matches[2]
        } else {
            throw "Unrecognised line in Project.mk: $line"
        }
    }

        # NAME is the only required key
        if (-not $cfg["NAME"]) { throw "Project.mk is missing NAME." }

        # Defaults (also applied when a key is present but empty)
        if (-not $cfg["TARGET"])      { $cfg["TARGET"]      = $cfg["NAME"] }
        if (-not $cfg["DESCRIPTION"]) { $cfg["DESCRIPTION"] = $cfg["NAME"] }
        if (-not $cfg["BIN"])         { $cfg["BIN"]         = "bin" }
        if (-not $cfg["BUILD"])       { $cfg["BUILD"]       = "build" }
        if (-not $cfg["SRCDIR"])      { $cfg["SRCDIR"]      = "src" }
        if (-not $cfg["INCLUDE"])     { $cfg["INCLUDE"]     = "include" }
        if (-not $cfg["RESOURCES"])   { $cfg["RESOURCES"]   = "resources" }
        if (-not $cfg["SRC"])         { $cfg["SRC"]         = "main.c" }


    # Normalize dirs
    # path stays relative to the project instead of becoming absolute
    foreach ($key in "BIN", "BUILD", "SRCDIR", "INCLUDE", "RESOURCES") {
        $cfg[$key] = $cfg[$key].Trim().Trim('/', '\')
    }

    return $cfg
}

function New-CBuildFile {
    param(
        [string]$Template,
        [string]$Destination,
        [hashtable]$Config,
        [string]$Shim = (Join-Path $HOME "cbuild/port_shim").Replace('\', '/')
    )

    $text = Get-Content -LiteralPath $Template -Raw

    $text = $text.Replace("CNAME", $Config.NAME).
                  Replace("CDESC", $Config.DESCRIPTION).
                  Replace("CTAR",  $Config.TARGET).
                  Replace("CBINDIR", $Config.BIN).
                  Replace("CBUILDDIR", $Config.BUILD).
                  Replace("CSRCDIR", $Config.SRCDIR).
                  Replace("CINCDIR", $Config.INCLUDE).
                  Replace("CSRCFILES", $Config.SRC).
                  Replace("port_shim/", "$Shim/")

    $dest = Join-Path $PWD.Path $Destination
    [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding $false))
}


# === Installer Functions === =====================================================================================================
function Uninstall-cbuild {
    param(
        [bool]$Full,
        [bool]$Force
    )

    $cedev = Join-Path $HOME "CEdev"
    $msys  = "C:\msys64"

    if (-not $Force) {
        $what = "cbuild, the CE toolchain, and the PATH/profile entries cbuild added"
        if ($Full) { $what += ", plus MSYS2 and the WSL build packages" }
        $answer = Read-Host "This will remove $what. Continue? (y/N)"
        if ($answer -notmatch '^(y|yes)$') {
            Write-Host "Uninstall cancelled."
            return
        }
    }

    Write-Host ">>> Uninstalling cbuild..."
    
    # Calculator toolchain
    Write-Host ">>> Removing calculator toolchain..."
    Remove-CBuildUserPath (Join-Path $cedev "bin")
    [Environment]::SetEnvironmentVariable("CEDEV", $null, "User")
    Remove-Item Env:\CEDEV -ErrorAction SilentlyContinue
    Remove-CBuildDirectory $cedev

    # Windows toolchain (PATH entry always; MSYS2 itself only with -all)
    Write-Host ">>> Removing Windows toolchain entries..."
    Remove-CBuildUserPath (Join-Path $msys "ucrt64\bin")

    if ($Full -and (Test-Path -LiteralPath $msys)) {
        Write-Host ">>> Uninstalling MSYS2..."
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            & winget uninstall MSYS2.MSYS2 --silent
        }
        Remove-CBuildDirectory $msys   # winget can leave the folder behind
    }

    # Linux packages (only with -all)
    if ($Full -and (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        $distros = ((& wsl.exe -l -q 2>$null) -join "`n") -replace "`0", ""
        if (-not [string]::IsNullOrWhiteSpace($distros)) {
            Write-Host ">>> Removing WSL build packages..."
            & wsl.exe -u root -- bash -c "apt-get remove -y cmake ninja-build libsdl2-dev"
            if ($LASTEXITCODE -ne 0) { Write-Warning "Could not remove the WSL packages." }
        }
    }
    
    # Remove from profile
    Remove-CBuildProfileLine

    # Finally remove cbuild completely
    Remove-CBuildDirectory $script:CBuildInstallDir

    Write-Host "`ncbuild uninstalled. Restart your terminal to finish." -ForegroundColor Blue
}

function Remove-CBuildUserPath {
    param([Parameter(Mandatory)][string]$Dir)

    $target = $Dir.TrimEnd('\')
    $keep = { $_ -and ($_.TrimEnd('\') -ne $target) }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath) {
        $parts = @($userPath -split ';' | Where-Object $keep)
        [Environment]::SetEnvironmentVariable("Path", ($parts -join ';'), "User")
    }
    $env:Path = (@($env:Path -split ';' | Where-Object $keep)) -join ';'
}

function Remove-CBuildDirectory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return }
    Write-Host "Deleting $Path"

    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $Path) {
        try { [System.IO.Directory]::Delete($Path, $true) }
        catch {
            Write-Warning "Could not fully delete $Path ($($_.Exception.Message)). Close anything using it and delete it manually."
        }
    }
}   

function Remove-CBuildProfileLine {
    if (-not (Test-Path -LiteralPath $PROFILE)) { return }

    $lines = @(Get-Content -LiteralPath $PROFILE)
    $kept  = @($lines | Where-Object { $_ -notmatch 'cbuild[\\/]cbuild\.ps1' })

    if ($kept.Count -ne $lines.Count) {
        [System.IO.File]::WriteAllLines($PROFILE, [string[]]$kept,
            (New-Object System.Text.UTF8Encoding $false))
        Write-Host "Removed cbuild from $PROFILE"
    }
}

function Install-cbuild() {
    param (
        [bool]$force
    )

    Write-Host ">>> Preparing cbuild installation..."
    $installDir = Join-Path $HOME "cbuild"

    if ((Test-Path -LiteralPath (Join-Path $installDir "requirements.txt")) -and -not $force) {
        Write-Host "cbuild is already installed! Use -force to reinstall."
        return
    }
    
    New-Item -ItemType Directory `
        -Path $installDir -Force | Out-Null

    $sourcePath = $PSCommandPath
    $targetPath = Join-Path $installDir "cbuild.ps1"

    if (-not $sourcePath) {
        throw "Cannot determine the source script path."
    }

    $sourceFullPath = [System.IO.Path]::GetFullPath($sourcePath)
    $targetFullPath = [System.IO.Path]::GetFullPath($targetPath)

    if (-not [string]::Equals(
        $sourceFullPath,
        $targetFullPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Copy-Item -LiteralPath $sourceFullPath `
            -Destination $targetFullPath -Force
    }

    # Install python
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "[Notice] Python is required to use cbuild. `n>>> Installing python..."
        & winget install Python.Python.3.11 --accept-package-agreements
    }

    # Update pip
    $ python -m pip install --upgrade pip

    # Install pillow
    & python -m pip install --quiet pillow
    if ($LASTEXITCODE -ne 0) { Write-Warning "Pillow install failed." }

    # === Install all the relevant cbuild files ===
    Write-Host ">>> Installing cbuild..."

    $requirements = @'
# === CBUILD ===

CBUILD
    - makefiles
    # - calc_shim
    - port_shim
    - python

PYTHON
    - pillow

CALCULATOR
    - CEdev

WINDOWS
    - GCC
    - cmake
    - ninja
    - SDL2

LINUX
    - WSL2
    - Ubuntu
'@

    Set-Content `
        -LiteralPath (Join-Path $installDir "requirements.txt") `
        -Value $requirements `
        -Encoding utf8

    # --- port_shim ---
    # directories
    $shimDir = Join-Path $InstallDir "port_shim"
    New-Item -ItemType Directory `
        -Path $shimDir -Force | Out-Null
    $includeDir = Join-Path $shimDir "include"
    New-Item -ItemType Directory `
        -Path $includeDir -Force | Out-Null
    $srcDir = Join-Path $shimDir "src"
    New-Item -ItemType Directory `
        -Path $srcDir -Force | Out-Null
    
    # include files
    $fileiocH = @'
#ifndef CE_SHIM_FILEIOC_H
#define CE_SHIM_FILEIOC_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <tice.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t ti_Open(const char *name, const char *mode);
int     ti_Close(uint8_t slot);
size_t  ti_Read(void *data, size_t size, size_t count, uint8_t slot);
size_t  ti_Write(const void *data, size_t size, size_t count, uint8_t slot);
int     ti_PutC(char ch, uint8_t slot);
int     ti_GetC(uint8_t slot);
int     ti_Seek(int offset, unsigned origin, uint8_t slot);
int     ti_Tell(uint8_t slot);
int     ti_Rewind(uint8_t slot);
uint16_t ti_GetSize(uint8_t slot);
void   *ti_GetDataPtr(uint8_t slot);
int     ti_Delete(const char *name);

#ifdef __cplusplus
}
#endif

#endif
'@
    
    $graphxH = @'
#ifndef CE_SHIM_GRAPHX_H
#define CE_SHIM_GRAPHX_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <tice.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GFX_LCD_WIDTH  320
#define GFX_LCD_HEIGHT 240

typedef struct gfx_sprite_t {
    uint8_t width;
    uint8_t height;
    uint8_t data[];
} gfx_sprite_t;

typedef struct gfx_tilemap_t {
    uint8_t *map;
    gfx_sprite_t **tiles;
    uint8_t tile_height;
    uint8_t tile_width;
    uint8_t draw_height;
    uint8_t draw_width;
    uint8_t type_width;
    uint8_t type_height;
    uint8_t height;
    uint8_t width;
    uint8_t y_loc;
    uint8_t x_loc;
} gfx_tilemap_t;

typedef enum { gfx_screen = 0, gfx_buffer = 1 } gfx_location_t;

typedef enum {
    gfx_tile_no_pow2 = 0,
    gfx_tile_2_pixel,
    gfx_tile_4_pixel,
    gfx_tile_8_pixel,
    gfx_tile_16_pixel,
    gfx_tile_32_pixel,
    gfx_tile_64_pixel,
    gfx_tile_128_pixel
} gfx_tilemap_type_t;

typedef enum { gfx_8bpp = 0x27 } gfx_mode_t;

#define gfx_RGBTo1555(r, g, b) \
    ((uint16_t)((((uint16_t)(r) & 0xF8) << 7) | (((uint16_t)(g) & 0xF8) << 2) | \
                (((uint16_t)(b) & 0xF8) >> 3) | (((uint16_t)(g) & 0x04) << 13)))

#define gfx_UninitedSprite(name, w, h) \
    uint8_t name##_data[2 + (w) * (h)]; \
    gfx_sprite_t *name = (gfx_sprite_t *)name##_data
#define gfx_TempSprite(name, w, h) gfx_UninitedSprite(name, w, h)
#define gfx_AllocSprite(w, h, malloc_routine) \
    ((gfx_sprite_t *)gfx_internal_init_sprite((malloc_routine)(2 + (size_t)(w) * (h)), (w), (h)))

gfx_sprite_t *gfx_internal_init_sprite(void *mem, uint8_t w, uint8_t h);
gfx_sprite_t *gfx_MallocSprite(uint8_t width, uint8_t height);

extern uint16_t gfx_palette[256];

void gfx_ShiftLeft(uint24_t pixels);
void gfx_ShiftRight(uint24_t pixels);
void gfx_ShiftUp(uint24_t pixels);
void gfx_ShiftDown(uint24_t pixels);

void gfx_Begin(void);
void gfx_End(void);
void gfx_SetPalette(const void *palette, uint24_t size, uint8_t offset);
void gfx_SetDefaultPalette(gfx_mode_t mode);

void gfx_SetDraw(uint8_t location);
uint8_t gfx_GetDraw(void);
void gfx_SetDrawScreen(void);
void gfx_SetDrawBuffer(void);
void gfx_SwapDraw(void);
void gfx_Wait(void);
void gfx_Blit(gfx_location_t src);
void gfx_BlitBuffer(void);
void gfx_BlitScreen(void);

uint8_t gfx_SetColor(uint8_t index);
uint8_t gfx_SetTransparentColor(uint8_t index);
void gfx_SetClipRegion(int xmin, int ymin, int xmax, int ymax);
void gfx_FillScreen(uint8_t color);
void gfx_ZeroScreen(void);

void gfx_SetPixel(uint24_t x, uint8_t y);
uint8_t gfx_GetPixel(uint24_t x, uint8_t y);
void gfx_Line(int x0, int y0, int x1, int y1);
void gfx_Line_NoClip(uint24_t x0, uint8_t y0, uint24_t x1, uint8_t y1);
void gfx_HorizLine(int x, int y, int length);
void gfx_HorizLine_NoClip(uint24_t x, uint8_t y, uint24_t length);
void gfx_VertLine(int x, int y, int length);
void gfx_VertLine_NoClip(uint24_t x, uint8_t y, uint24_t length);
void gfx_Rectangle(int x, int y, int width, int height);
void gfx_Rectangle_NoClip(uint24_t x, uint8_t y, uint24_t width, uint8_t height);
void gfx_FillRectangle(int x, int y, int width, int height);
void gfx_FillRectangle_NoClip(uint24_t x, uint8_t y, uint24_t width, uint8_t height);
void gfx_Circle(int x, int y, uint24_t radius);
void gfx_FillCircle(int x, int y, uint24_t radius);
void gfx_Circle_NoClip(uint24_t x, uint8_t y, uint8_t radius);
void gfx_FillCircle_NoClip(uint24_t x, uint8_t y, uint8_t radius);

void gfx_Sprite(const gfx_sprite_t *sprite, int x, int y);
void gfx_Sprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y);
void gfx_TransparentSprite(const gfx_sprite_t *sprite, int x, int y);
void gfx_TransparentSprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y);
void gfx_ScaledSprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y,
                             uint8_t width_scale, uint8_t height_scale);
void gfx_ScaledTransparentSprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y,
                                        uint8_t width_scale, uint8_t height_scale);
gfx_sprite_t *gfx_GetSprite(gfx_sprite_t *sprite_buffer, int x, int y);
gfx_sprite_t *gfx_FlipSpriteY(const gfx_sprite_t *sprite_in, gfx_sprite_t *sprite_out);
gfx_sprite_t *gfx_FlipSpriteX(const gfx_sprite_t *sprite_in, gfx_sprite_t *sprite_out);

void gfx_Tilemap(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);
void gfx_Tilemap_NoClip(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);
void gfx_TransparentTilemap(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);
void gfx_TransparentTilemap_NoClip(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);

void gfx_PrintChar(const char c);
void gfx_PrintInt(int n, uint8_t length);
void gfx_PrintUInt(unsigned int n, uint8_t length);
void gfx_PrintString(const char *string);
void gfx_PrintStringXY(const char *string, int x, int y);
void gfx_SetTextXY(int x, int y);
int gfx_GetTextX(void);
int gfx_GetTextY(void);
uint8_t gfx_SetTextFGColor(uint8_t color);
uint8_t gfx_SetTextBGColor(uint8_t color);
uint8_t gfx_SetTextTransparentColor(uint8_t color);
void gfx_SetTextScale(uint8_t width_scale, uint8_t height_scale);
uint24_t gfx_GetStringWidth(const char *string);
uint24_t gfx_GetCharWidth(const char c);

#ifdef __cplusplus
}
#endif

#endif
'@

    $keypadcH = @'
#ifndef CE_SHIM_KEYPADC_H
#define CE_SHIM_KEYPADC_H

#include <stdint.h>
#include <stdbool.h>
#include <tice.h>

#ifdef __cplusplus
extern "C" {
#endif

extern volatile uint16_t kb_Data[8];

typedef enum {
    kb_KeyGraph = 0x0101, kb_KeyTrace = 0x0102, kb_KeyZoom = 0x0104, kb_KeyWindow = 0x0108,
    kb_KeyYequ = 0x0110, kb_Key2nd = 0x0120, kb_KeyMode = 0x0140, kb_KeyDel = 0x0180,
    kb_KeySto = 0x0202, kb_KeyLn = 0x0204, kb_KeyLog = 0x0208, kb_KeySquare = 0x0210,
    kb_KeyRecip = 0x0220, kb_KeyMath = 0x0240, kb_KeyAlpha = 0x0280,
    kb_Key0 = 0x0301, kb_Key1 = 0x0302, kb_Key4 = 0x0304, kb_Key7 = 0x0308,
    kb_KeyComma = 0x0310, kb_KeySin = 0x0320, kb_KeyApps = 0x0340, kb_KeyGraphVar = 0x0380,
    kb_KeyDecPnt = 0x0401, kb_Key2 = 0x0402, kb_Key5 = 0x0404, kb_Key8 = 0x0408,
    kb_KeyLParen = 0x0410, kb_KeyCos = 0x0420, kb_KeyPrgm = 0x0440, kb_KeyStat = 0x0480,
    kb_KeyChs = 0x0501, kb_Key3 = 0x0502, kb_Key6 = 0x0504, kb_Key9 = 0x0508,
    kb_KeyRParen = 0x0510, kb_KeyTan = 0x0520, kb_KeyVars = 0x0540,
    kb_KeyEnter = 0x0601, kb_KeyAdd = 0x0602, kb_KeySub = 0x0604, kb_KeyMul = 0x0608,
    kb_KeyDiv = 0x0610, kb_KeyPower = 0x0620, kb_KeyClear = 0x0640,
    kb_KeyDown = 0x0701, kb_KeyLeft = 0x0702, kb_KeyRight = 0x0704, kb_KeyUp = 0x0708
} kb_lkey_t;

typedef enum {
    kb_group_1 = 1, kb_group_2, kb_group_3, kb_group_4, kb_group_5, kb_group_6, kb_group_7
} kb_group_t;

#define kb_Graph 0x01
#define kb_Trace 0x02
#define kb_Zoom 0x04
#define kb_Window 0x08
#define kb_Yequ 0x10
#define kb_2nd 0x20
#define kb_Mode 0x40
#define kb_Del 0x80
#define kb_Sto 0x02
#define kb_Ln 0x04
#define kb_Log 0x08
#define kb_Square 0x10
#define kb_Recip 0x20
#define kb_Math 0x40
#define kb_Alpha 0x80
#define kb_0 0x01
#define kb_1 0x02
#define kb_4 0x04
#define kb_7 0x08
#define kb_Comma 0x10
#define kb_Sin 0x20
#define kb_Apps 0x40
#define kb_GraphVar 0x80
#define kb_DecPnt 0x01
#define kb_2 0x02
#define kb_5 0x04
#define kb_8 0x08
#define kb_LParen 0x10
#define kb_Cos 0x20
#define kb_Prgm 0x40
#define kb_Stat 0x80
#define kb_Chs 0x01
#define kb_3 0x02
#define kb_6 0x04
#define kb_9 0x08
#define kb_RParen 0x10
#define kb_Tan 0x20
#define kb_Vars 0x40
#define kb_Enter 0x01
#define kb_Add 0x02
#define kb_Sub 0x04
#define kb_Mul 0x08
#define kb_Div 0x10
#define kb_Power 0x20
#define kb_Clear 0x40
#define kb_Down 0x01
#define kb_Left 0x02
#define kb_Right 0x04
#define kb_Up 0x08

#define kb_IsDown(key) ((kb_Data[((key) >> 8) & 7] & ((key) & 0xFF)) ? 1 : 0)

typedef enum { MODE_0_IDLE = 0, MODE_1_INDIRECT, MODE_2_SINGLE, MODE_3_CONTINUOUS } kb_mode_t;

void kb_Scan(void);
uint8_t kb_ScanGroup(uint8_t row);
uint8_t kb_AnyKey(void);
void kb_Reset(void);
void kb_SetMode(uint8_t mode);
void kb_DisableOnLatch(void);
void kb_ClearOnLatch(void);
bool kb_On(void);

#ifdef __cplusplus
}
#endif

#endif
'@

    $ticeH = @'
#ifndef CE_SHIM_TICE_H
#define CE_SHIM_TICE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

#ifdef _WIN32
static inline int random(void) { return rand(); }
static inline void srandom(unsigned int seed) { srand(seed); }
#endif

typedef uint32_t uint24_t;
typedef int32_t  int24_t;

#endif
'@

    # src files
    $ce_internalH = @'
#ifndef CE_INTERNAL_H
#define CE_INTERNAL_H

void ce_present_if_due(void);
int  ce_video_ready(void);

#endif

'@

    $fileiocC = @'
#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fileioc.h"

#define MAX_SLOTS 6

typedef struct {
    FILE *fp;
    void *snapshot;
} Slot;

static Slot slots[MAX_SLOTS];
static char *base_dir = NULL;

static const char *get_base(void)
{
    if (!base_dir) {
        char *p = SDL_GetPrefPath("ce-desktop-port", "game");
        base_dir = p ? p : SDL_strdup("./");
    }
    return base_dir;
}

static void make_path(const char *name, char *out, size_t n)
{
    snprintf(out, n, "%s%s.8xv", get_base(), name);
}

uint8_t ti_Open(const char *name, const char *mode)
{
    char path[1024];
    make_path(name, path, sizeof path);

    char m[8];
    size_t len = strlen(mode);
    if (len + 2 > sizeof m) return 0;
    memcpy(m, mode, len);
    if (strchr(mode, 'b') == NULL) { m[len] = 'b'; m[len + 1] = '\0'; }
    else m[len] = '\0';

    for (int i = 1; i < MAX_SLOTS; i++) {
        if (!slots[i].fp) {
            FILE *fp = fopen(path, m);
            if (!fp) return 0;
            slots[i].fp = fp;
            slots[i].snapshot = NULL;
            return (uint8_t)i;
        }
    }
    return 0;
}

static FILE *get(uint8_t slot)
{
    return (slot > 0 && slot < MAX_SLOTS) ? slots[slot].fp : NULL;
}

int ti_Close(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return 0;
    fclose(fp);
    free(slots[slot].snapshot);
    slots[slot].fp = NULL;
    slots[slot].snapshot = NULL;
    return 1;
}

size_t ti_Read(void *data, size_t size, size_t count, uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fread(data, size, count, fp) : 0;
}

size_t ti_Write(const void *data, size_t size, size_t count, uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fwrite(data, size, count, fp) : 0;
}

int ti_PutC(char ch, uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fputc((unsigned char)ch, fp) : -1;
}

int ti_GetC(uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fgetc(fp) : -1;
}

int ti_Seek(int offset, unsigned origin, uint8_t slot)
{
    FILE *fp = get(slot);
    return (fp && fseek(fp, offset, (int)origin) == 0) ? offset : -1;
}

int ti_Tell(uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? (int)ftell(fp) : -1;
}

int ti_Rewind(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return -1;
    rewind(fp);
    return 0;
}

uint16_t ti_GetSize(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return 0;
    long cur = ftell(fp);
    fseek(fp, 0, SEEK_END);
    long end = ftell(fp);
    fseek(fp, cur, SEEK_SET);
    return (uint16_t)end;
}

void *ti_GetDataPtr(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return NULL;
    long cur = ftell(fp);
    fflush(fp);
    fseek(fp, 0, SEEK_END);
    long end = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    free(slots[slot].snapshot);
    slots[slot].snapshot = malloc((size_t)end + 1);
    if (slots[slot].snapshot) {
        size_t got = fread(slots[slot].snapshot, 1, (size_t)end, fp);
        (void)got;
    }
    fseek(fp, cur, SEEK_SET);
    return slots[slot].snapshot;
}

int ti_Delete(const char *name)
{
    char path[1024];
    make_path(name, path, sizeof path);
    return remove(path) == 0;
}
'@

    $graphxC = @'
#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "graphx.h"
#include "ce_internal.h"

#define W GFX_LCD_WIDTH
#define H GFX_LCD_HEIGHT

#ifndef CE_WINDOW_TITLE
#define CE_WINDOW_TITLE "CE Game (desktop)"
#endif


static const uint8_t font8x8[95][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, {0x18,0x3C,0x3C,0x18,0x18,0x00,0x18,0x00},
    {0x36,0x36,0x00,0x00,0x00,0x00,0x00,0x00}, {0x36,0x36,0x7F,0x36,0x7F,0x36,0x36,0x00},
    {0x0C,0x3E,0x03,0x1E,0x30,0x1F,0x0C,0x00}, {0x00,0x63,0x33,0x18,0x0C,0x66,0x63,0x00},
    {0x1C,0x36,0x1C,0x6E,0x3B,0x33,0x6E,0x00}, {0x06,0x06,0x03,0x00,0x00,0x00,0x00,0x00},
    {0x18,0x0C,0x06,0x06,0x06,0x0C,0x18,0x00}, {0x06,0x0C,0x18,0x18,0x18,0x0C,0x06,0x00},
    {0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00}, {0x00,0x0C,0x0C,0x3F,0x0C,0x0C,0x00,0x00},
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x06}, {0x00,0x00,0x00,0x3F,0x00,0x00,0x00,0x00},
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x00}, {0x60,0x30,0x18,0x0C,0x06,0x03,0x01,0x00},
    {0x3E,0x63,0x73,0x7B,0x6F,0x67,0x3E,0x00}, {0x0C,0x0E,0x0C,0x0C,0x0C,0x0C,0x3F,0x00},
    {0x1E,0x33,0x30,0x1C,0x06,0x33,0x3F,0x00}, {0x1E,0x33,0x30,0x1C,0x30,0x33,0x1E,0x00},
    {0x38,0x3C,0x36,0x33,0x7F,0x30,0x78,0x00}, {0x3F,0x03,0x1F,0x30,0x30,0x33,0x1E,0x00},
    {0x1C,0x06,0x03,0x1F,0x33,0x33,0x1E,0x00}, {0x3F,0x33,0x30,0x18,0x0C,0x0C,0x0C,0x00},
    {0x1E,0x33,0x33,0x1E,0x33,0x33,0x1E,0x00}, {0x1E,0x33,0x33,0x3E,0x30,0x18,0x0E,0x00},
    {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x00}, {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x06},
    {0x18,0x0C,0x06,0x03,0x06,0x0C,0x18,0x00}, {0x00,0x00,0x3F,0x00,0x00,0x3F,0x00,0x00},
    {0x06,0x0C,0x18,0x30,0x18,0x0C,0x06,0x00}, {0x1E,0x33,0x30,0x18,0x0C,0x00,0x0C,0x00},
    {0x3E,0x63,0x7B,0x7B,0x7B,0x03,0x1E,0x00}, {0x0C,0x1E,0x33,0x33,0x3F,0x33,0x33,0x00},
    {0x3F,0x66,0x66,0x3E,0x66,0x66,0x3F,0x00}, {0x3C,0x66,0x03,0x03,0x03,0x66,0x3C,0x00},
    {0x1F,0x36,0x66,0x66,0x66,0x36,0x1F,0x00}, {0x7F,0x46,0x16,0x1E,0x16,0x46,0x7F,0x00},
    {0x7F,0x46,0x16,0x1E,0x16,0x06,0x0F,0x00}, {0x3C,0x66,0x03,0x03,0x73,0x66,0x7C,0x00},
    {0x33,0x33,0x33,0x3F,0x33,0x33,0x33,0x00}, {0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00},
    {0x78,0x30,0x30,0x30,0x33,0x33,0x1E,0x00}, {0x67,0x66,0x36,0x1E,0x36,0x66,0x67,0x00},
    {0x0F,0x06,0x06,0x06,0x46,0x66,0x7F,0x00}, {0x63,0x77,0x7F,0x7F,0x6B,0x63,0x63,0x00},
    {0x63,0x67,0x6F,0x7B,0x73,0x63,0x63,0x00}, {0x1C,0x36,0x63,0x63,0x63,0x36,0x1C,0x00},
    {0x3F,0x66,0x66,0x3E,0x06,0x06,0x0F,0x00}, {0x1E,0x33,0x33,0x33,0x3B,0x1E,0x38,0x00},
    {0x3F,0x66,0x66,0x3E,0x36,0x66,0x67,0x00}, {0x1E,0x33,0x07,0x0E,0x38,0x33,0x1E,0x00},
    {0x3F,0x2D,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, {0x33,0x33,0x33,0x33,0x33,0x33,0x3F,0x00},
    {0x33,0x33,0x33,0x33,0x33,0x1E,0x0C,0x00}, {0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00},
    {0x63,0x63,0x36,0x1C,0x1C,0x36,0x63,0x00}, {0x33,0x33,0x33,0x1E,0x0C,0x0C,0x1E,0x00},
    {0x7F,0x63,0x31,0x18,0x4C,0x66,0x7F,0x00}, {0x1E,0x06,0x06,0x06,0x06,0x06,0x1E,0x00},
    {0x03,0x06,0x0C,0x18,0x30,0x60,0x40,0x00}, {0x1E,0x18,0x18,0x18,0x18,0x18,0x1E,0x00},
    {0x08,0x1C,0x36,0x63,0x00,0x00,0x00,0x00}, {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF},
    {0x0C,0x0C,0x18,0x00,0x00,0x00,0x00,0x00}, {0x00,0x00,0x1E,0x30,0x3E,0x33,0x6E,0x00},
    {0x07,0x06,0x06,0x3E,0x66,0x66,0x3B,0x00}, {0x00,0x00,0x1E,0x33,0x03,0x33,0x1E,0x00},
    {0x38,0x30,0x30,0x3E,0x33,0x33,0x6E,0x00}, {0x00,0x00,0x1E,0x33,0x3F,0x03,0x1E,0x00},
    {0x1C,0x36,0x06,0x0F,0x06,0x06,0x0F,0x00}, {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x1F},
    {0x07,0x06,0x36,0x6E,0x66,0x66,0x67,0x00}, {0x0C,0x00,0x0E,0x0C,0x0C,0x0C,0x1E,0x00},
    {0x30,0x00,0x30,0x30,0x30,0x33,0x33,0x1E}, {0x07,0x06,0x66,0x36,0x1E,0x36,0x67,0x00},
    {0x0E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, {0x00,0x00,0x33,0x7F,0x7F,0x6B,0x63,0x00},
    {0x00,0x00,0x1F,0x33,0x33,0x33,0x33,0x00}, {0x00,0x00,0x1E,0x33,0x33,0x33,0x1E,0x00},
    {0x00,0x00,0x3B,0x66,0x66,0x3E,0x06,0x0F}, {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x78},
    {0x00,0x00,0x3B,0x6E,0x66,0x06,0x0F,0x00}, {0x00,0x00,0x3E,0x03,0x1E,0x30,0x1F,0x00},
    {0x08,0x0C,0x3E,0x0C,0x0C,0x2C,0x18,0x00}, {0x00,0x00,0x33,0x33,0x33,0x33,0x6E,0x00},
    {0x00,0x00,0x33,0x33,0x33,0x1E,0x0C,0x00}, {0x00,0x00,0x63,0x6B,0x7F,0x7F,0x36,0x00},
    {0x00,0x00,0x63,0x36,0x1C,0x36,0x63,0x00}, {0x00,0x00,0x33,0x33,0x33,0x3E,0x30,0x1F},
    {0x00,0x00,0x3F,0x19,0x0C,0x26,0x3F,0x00}, {0x38,0x0C,0x0C,0x07,0x0C,0x0C,0x38,0x00},
    {0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00}, {0x07,0x0C,0x0C,0x38,0x0C,0x0C,0x07,0x00},
    {0x6E,0x3B,0x00,0x00,0x00,0x00,0x00,0x00}
};

static SDL_Window   *window;
static SDL_Renderer *renderer;
static SDL_Texture  *texture;

static uint8_t  bufs[2][W * H];
static uint8_t *display_buf = bufs[0];
static uint8_t *draw_buf    = bufs[1];
uint16_t gfx_palette[256];

static uint8_t  color_idx = 0;
static uint8_t  transparent_idx = 0;
static int      clip_x0 = 0, clip_y0 = 0, clip_x1 = W, clip_y1 = H;

static int      text_x = 0, text_y = 0;
static uint8_t  text_fg = 0, text_bg = 255, text_trans = 255;
static uint8_t  text_sx = 1, text_sy = 1;

static uint32_t last_present = 0;

int ce_video_ready(void) { return window != NULL; }

static uint32_t from_1555(uint16_t v)
{
    unsigned r5 = (v >> 10) & 31, b5 = v & 31;
    unsigned g6 = (((v >> 5) & 31) << 1) | (v >> 15);
    unsigned r = (r5 << 3) | (r5 >> 2), g = (g6 << 2) | (g6 >> 4), b = (b5 << 3) | (b5 >> 2);
    return 0xFF000000u | (r << 16) | (g << 8) | b;
}

void gfx_SetDefaultPalette(gfx_mode_t mode)
{
    (void)mode;
    for (int i = 0; i < 256; i++) {
        unsigned r = (i >> 5) & 7, g = (i >> 2) & 7, b = i & 3;
        r = (r << 5) | (r << 2) | (r >> 1);
        g = (g << 5) | (g << 2) | (g >> 1);
        b = (b << 6) | (b << 4) | (b << 2) | b;
        gfx_palette[i] = gfx_RGBTo1555(r, g, b);
    }
}

void gfx_SetPalette(const void *palette, uint24_t size, uint8_t offset)
{
    const uint8_t *p = (const uint8_t *)palette;
    unsigned count = size / 2;
    for (unsigned i = 0; i < count && (offset + i) < 256; i++) {
        gfx_palette[offset + i] = (uint16_t)(p[2 * i] | (p[2 * i + 1] << 8));
    }
}

static void present(void)
{
    if (!window) return;
    uint32_t palette_argb[256];
    for (int i = 0; i < 256; i++) palette_argb[i] = from_1555(gfx_palette[i]);

    void *pixels; int pitch;
    if (SDL_LockTexture(texture, NULL, &pixels, &pitch) == 0) {
        for (int y = 0; y < H; y++) {
            uint32_t *row = (uint32_t *)((uint8_t *)pixels + y * pitch);
            const uint8_t *src = display_buf + y * W;
            for (int x = 0; x < W; x++) row[x] = palette_argb[src[x]];
        }
        SDL_UnlockTexture(texture);
    }
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);
    last_present = SDL_GetTicks();
}

void ce_present_if_due(void)
{
    if (window && SDL_GetTicks() - last_present >= 16) present();
}

static void throttle_and_present(void)
{
    uint32_t now = SDL_GetTicks();
    if (now - last_present < 16) SDL_Delay(16 - (now - last_present));
    present();
}

void gfx_Begin(void)
{
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        exit(1);
    }
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");
    window = SDL_CreateWindow(CE_WINDOW_TITLE, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              W * 2, H * 2, SDL_WINDOW_RESIZABLE);
    if (!window) { fprintf(stderr, "Window failed: %s\n", SDL_GetError()); exit(1); }
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    if (!renderer) { fprintf(stderr, "Renderer failed: %s\n", SDL_GetError()); exit(1); }
    SDL_RenderSetLogicalSize(renderer, W, H);
    SDL_RenderSetIntegerScale(renderer, SDL_TRUE);
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, W, H);

    gfx_SetDefaultPalette(gfx_8bpp);
    memset(bufs, 0, sizeof bufs);
    display_buf = bufs[0];
    draw_buf = bufs[1];
    color_idx = 0; transparent_idx = 0;
    clip_x0 = 0; clip_y0 = 0; clip_x1 = W; clip_y1 = H;
    text_x = text_y = 0; text_fg = 0; text_bg = 255; text_trans = 255; text_sx = text_sy = 1;
    present();
}

void gfx_End(void)
{
    if (texture)  SDL_DestroyTexture(texture);
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window)   SDL_DestroyWindow(window);
    texture = NULL; renderer = NULL; window = NULL;
    SDL_Quit();
}

static uint8_t *other_buf(void) { return display_buf == bufs[0] ? bufs[1] : bufs[0]; }

void gfx_SetDraw(uint8_t location) { draw_buf = (location == gfx_screen) ? display_buf : other_buf(); }
uint8_t gfx_GetDraw(void) { return draw_buf == display_buf ? gfx_screen : gfx_buffer; }
void gfx_SetDrawScreen(void) { gfx_SetDraw(gfx_screen); }
void gfx_SetDrawBuffer(void) { gfx_SetDraw(gfx_buffer); }

void gfx_SwapDraw(void)
{
    uint8_t *old_display = display_buf;
    display_buf = draw_buf;
    draw_buf = old_display;
    throttle_and_present();
}

void gfx_Wait(void) { throttle_and_present(); }

void gfx_Blit(gfx_location_t src)
{
    if (src == gfx_buffer) memcpy(display_buf, other_buf(), W * H);
    else                   memcpy(other_buf(), display_buf, W * H);
    throttle_and_present();
}
void gfx_BlitBuffer(void) { gfx_Blit(gfx_buffer); }
void gfx_BlitScreen(void) { gfx_Blit(gfx_screen); }

uint8_t gfx_SetColor(uint8_t i) { uint8_t o = color_idx; color_idx = i; return o; }
uint8_t gfx_SetTransparentColor(uint8_t i) { uint8_t o = transparent_idx; transparent_idx = i; return o; }

void gfx_SetClipRegion(int xmin, int ymin, int xmax, int ymax)
{
    clip_x0 = xmin < 0 ? 0 : xmin;
    clip_y0 = ymin < 0 ? 0 : ymin;
    clip_x1 = xmax > W ? W : xmax;
    clip_y1 = ymax > H ? H : ymax;
}

void gfx_FillScreen(uint8_t c) { memset(draw_buf, c, W * H); }
void gfx_ZeroScreen(void) { memset(draw_buf, 0, W * H); }

static inline void put(int x, int y, uint8_t c)
{
    if (x >= clip_x0 && x < clip_x1 && y >= clip_y0 && y < clip_y1) draw_buf[y * W + x] = c;
}

void gfx_SetPixel(uint24_t x, uint8_t y) { put((int)x, y, color_idx); }
uint8_t gfx_GetPixel(uint24_t x, uint8_t y)
{
    return (x < W && y < H) ? draw_buf[y * W + x] : 0;
}

void gfx_HorizLine(int x, int y, int len)
{
    if (len <= 0 || y < clip_y0 || y >= clip_y1) return;
    int x0 = x < clip_x0 ? clip_x0 : x, x1 = (x + len) > clip_x1 ? clip_x1 : (x + len);
    if (x1 > x0) memset(draw_buf + y * W + x0, color_idx, x1 - x0);
}
void gfx_HorizLine_NoClip(uint24_t x, uint8_t y, uint24_t len) { gfx_HorizLine((int)x, y, (int)len); }

void gfx_VertLine(int x, int y, int len)
{
    if (len <= 0 || x < clip_x0 || x >= clip_x1) return;
    int y0 = y < clip_y0 ? clip_y0 : y, y1 = (y + len) > clip_y1 ? clip_y1 : (y + len);
    for (int j = y0; j < y1; j++) draw_buf[j * W + x] = color_idx;
}
void gfx_VertLine_NoClip(uint24_t x, uint8_t y, uint24_t len) { gfx_VertLine((int)x, y, (int)len); }

void gfx_Line(int x0, int y0, int x1, int y1)
{
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    for (;;) {
        put(x0, y0, color_idx);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}
void gfx_Line_NoClip(uint24_t x0, uint8_t y0, uint24_t x1, uint8_t y1) { gfx_Line((int)x0, y0, (int)x1, y1); }

void gfx_FillRectangle(int x, int y, int w, int h)
{
    for (int j = 0; j < h; j++) gfx_HorizLine(x, y + j, w);
}
void gfx_FillRectangle_NoClip(uint24_t x, uint8_t y, uint24_t w, uint8_t h) { gfx_FillRectangle((int)x, y, (int)w, h); }

void gfx_Rectangle(int x, int y, int w, int h)
{
    if (w <= 0 || h <= 0) return;
    gfx_HorizLine(x, y, w);
    gfx_HorizLine(x, y + h - 1, w);
    gfx_VertLine(x, y, h);
    gfx_VertLine(x + w - 1, y, h);
}
void gfx_Rectangle_NoClip(uint24_t x, uint8_t y, uint24_t w, uint8_t h) { gfx_Rectangle((int)x, y, (int)w, h); }

void gfx_Circle(int cx, int cy, uint24_t radius)
{
    int x = (int)radius, y = 0, err = 1 - x;
    while (x >= y) {
        put(cx + x, cy + y, color_idx); put(cx + y, cy + x, color_idx);
        put(cx - y, cy + x, color_idx); put(cx - x, cy + y, color_idx);
        put(cx - x, cy - y, color_idx); put(cx - y, cy - x, color_idx);
        put(cx + y, cy - x, color_idx); put(cx + x, cy - y, color_idx);
        y++;
        if (err < 0) err += 2 * y + 1;
        else { x--; err += 2 * (y - x) + 1; }
    }
}
void gfx_Circle_NoClip(uint24_t x, uint8_t y, uint8_t r) { gfx_Circle((int)x, y, r); }

void gfx_FillCircle(int cx, int cy, uint24_t radius)
{
    int r = (int)radius;
    for (int dy = -r; dy <= r; dy++) {
        int dx = (int)floor(sqrt((double)(r * r - dy * dy)) + 0.5);
        gfx_HorizLine(cx - dx, cy + dy, 2 * dx + 1);
    }
}
void gfx_FillCircle_NoClip(uint24_t x, uint8_t y, uint8_t r) { gfx_FillCircle((int)x, y, r); }

gfx_sprite_t *gfx_internal_init_sprite(void *mem, uint8_t w, uint8_t h)
{
    gfx_sprite_t *s = (gfx_sprite_t *)mem;
    if (s) { s->width = w; s->height = h; }
    return s;
}

gfx_sprite_t *gfx_MallocSprite(uint8_t w, uint8_t h)
{
    return gfx_internal_init_sprite(malloc(2 + (size_t)w * h), w, h);
}

void gfx_ShiftLeft(uint24_t n)
{
    if (n == 0 || n >= W) return;
    for (int y = 0; y < H; y++) memmove(draw_buf + y * W, draw_buf + y * W + n, W - n);
}
void gfx_ShiftRight(uint24_t n)
{
    if (n == 0 || n >= W) return;
    for (int y = 0; y < H; y++) memmove(draw_buf + y * W + n, draw_buf + y * W, W - n);
}
void gfx_ShiftUp(uint24_t n)
{
    if (n == 0 || n >= H) return;
    memmove(draw_buf, draw_buf + n * W, (size_t)(H - n) * W);
}
void gfx_ShiftDown(uint24_t n)
{
    if (n == 0 || n >= H) return;
    memmove(draw_buf + n * W, draw_buf, (size_t)(H - n) * W);
}

static void blit_sprite(const gfx_sprite_t *s, int x, int y, int sw, int sh, int transparent)
{
    if (!s || sw < 1 || sh < 1) return;
    for (int j = 0; j < s->height; j++) {
        for (int i = 0; i < s->width; i++) {
            uint8_t c = s->data[j * s->width + i];
            if (transparent && c == transparent_idx) continue;
            for (int b = 0; b < sh; b++)
                for (int a = 0; a < sw; a++)
                    put(x + i * sw + a, y + j * sh + b, c);
        }
    }
}

void gfx_Sprite(const gfx_sprite_t *s, int x, int y) { blit_sprite(s, x, y, 1, 1, 0); }
void gfx_Sprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y) { blit_sprite(s, (int)x, y, 1, 1, 0); }
void gfx_TransparentSprite(const gfx_sprite_t *s, int x, int y) { blit_sprite(s, x, y, 1, 1, 1); }
void gfx_TransparentSprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y) { blit_sprite(s, (int)x, y, 1, 1, 1); }
void gfx_ScaledSprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y, uint8_t ws, uint8_t hs)
{ blit_sprite(s, (int)x, y, ws, hs, 0); }
void gfx_ScaledTransparentSprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y, uint8_t ws, uint8_t hs)
{ blit_sprite(s, (int)x, y, ws, hs, 1); }

gfx_sprite_t *gfx_GetSprite(gfx_sprite_t *out, int x, int y)
{
    for (int j = 0; j < out->height; j++)
        for (int i = 0; i < out->width; i++) {
            int px = x + i, py = y + j;
            out->data[j * out->width + i] =
                (px >= 0 && px < W && py >= 0 && py < H) ? draw_buf[py * W + px] : 0;
        }
    return out;
}

gfx_sprite_t *gfx_FlipSpriteY(const gfx_sprite_t *in, gfx_sprite_t *out)
{
    out->width = in->width; out->height = in->height;
    for (int j = 0; j < in->height; j++)
        for (int i = 0; i < in->width; i++)
            out->data[j * in->width + (in->width - 1 - i)] = in->data[j * in->width + i];
    return out;
}

gfx_sprite_t *gfx_FlipSpriteX(const gfx_sprite_t *in, gfx_sprite_t *out)
{
    out->width = in->width; out->height = in->height;
    for (int j = 0; j < in->height; j++)
        for (int i = 0; i < in->width; i++)
            out->data[(in->height - 1 - j) * in->width + i] = in->data[j * in->width + i];
    return out;
}

static void draw_tilemap(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo, int transparent)
{
    unsigned tw = t->tile_width ? t->tile_width : 1, th = t->tile_height ? t->tile_height : 1;
    unsigned col0 = xo / tw, row0 = yo / th;
    int px0 = (int)t->x_loc - (int)(xo % tw), py0 = (int)t->y_loc - (int)(yo % th);
    for (unsigned r = 0; r < t->draw_height; r++) {
        for (unsigned c = 0; c < t->draw_width; c++) {
            unsigned mc = col0 + c, mr = row0 + r;
            if (mc >= t->width || mr >= t->height) continue;
            const gfx_sprite_t *s = t->tiles[t->map[mr * t->width + mc]];
            blit_sprite(s, px0 + (int)(c * tw), py0 + (int)(r * th), 1, 1, transparent);
        }
    }
}
void gfx_Tilemap(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 0); }
void gfx_Tilemap_NoClip(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 0); }
void gfx_TransparentTilemap(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 1); }
void gfx_TransparentTilemap_NoClip(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 1); }

uint8_t gfx_SetTextFGColor(uint8_t c) { uint8_t o = text_fg; text_fg = c; return o; }
uint8_t gfx_SetTextBGColor(uint8_t c) { uint8_t o = text_bg; text_bg = c; return o; }
uint8_t gfx_SetTextTransparentColor(uint8_t c) { uint8_t o = text_trans; text_trans = c; return o; }
void gfx_SetTextScale(uint8_t ws, uint8_t hs) { text_sx = ws ? ws : 1; text_sy = hs ? hs : 1; }
void gfx_SetTextXY(int x, int y) { text_x = x; text_y = y; }
int gfx_GetTextX(void) { return text_x; }
int gfx_GetTextY(void) { return text_y; }
uint24_t gfx_GetCharWidth(const char c) { (void)c; return 8u * text_sx; }
uint24_t gfx_GetStringWidth(const char *s) { return (uint24_t)strlen(s) * 8u * text_sx; }

void gfx_PrintChar(const char ch)
{
    unsigned idx = (unsigned char)ch;
    if (idx < 32 || idx > 126) idx = '?';
    const uint8_t *g = font8x8[idx - 32];

    uint8_t saved = color_idx;
    if (text_bg != text_trans) {
        color_idx = text_bg;
        gfx_FillRectangle(text_x, text_y, 8 * text_sx, 8 * text_sy);
    }
    color_idx = text_fg;
    for (int row = 0; row < 8; row++)
        for (int col = 0; col < 8; col++)
            if ((g[row] >> col) & 1)
                gfx_FillRectangle(text_x + col * text_sx, text_y + row * text_sy, text_sx, text_sy);
    color_idx = saved;
    text_x += 8 * text_sx;
}

void gfx_PrintString(const char *s) { while (*s) gfx_PrintChar(*s++); }

void gfx_PrintStringXY(const char *s, int x, int y)
{
    gfx_SetTextXY(x, y);
    gfx_PrintString(s);
}

void gfx_PrintInt(int n, uint8_t length)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%0*d", (int)length, n);
    gfx_PrintString(buf);
}

void gfx_PrintUInt(unsigned int n, uint8_t length)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%0*u", (int)length, n);
    gfx_PrintString(buf);
}
'@

    $keypadcC = @'
#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <stdlib.h>

#include "keypadc.h"
#include "ce_internal.h"

volatile uint16_t kb_Data[8];

/*
 * Desktop key bindings (calculator key -> keyboard key):
 *   D-pad   = Arrow keys        2nd   = Z        Alpha = X
 *   Clear   = C                 Mode  = Esc      Del   = Backspace
 *   Enter   = Return            Graph/Trace/Zoom/Window/Y= = F5/F4/F3/F2/F1
 *   Stat = S, Prgm = P, Vars = V, Math = M
 *   0-9 = number row, + - * / = keypad
 * Closing the window behaves like the game's Mode+2nd force-exit combo.
 */
typedef struct { SDL_Scancode sc; uint8_t group; uint8_t mask; } KeyMap;

static const KeyMap keymap[] = {
    { SDL_SCANCODE_DOWN, 7, 0x01 }, { SDL_SCANCODE_LEFT, 7, 0x02 },
    { SDL_SCANCODE_RIGHT, 7, 0x04 }, { SDL_SCANCODE_UP, 7, 0x08 },
    { SDL_SCANCODE_Z, 1, 0x20 },          /* 2nd   */
    { SDL_SCANCODE_X, 2, 0x80 },          /* Alpha */
    { SDL_SCANCODE_C, 6, 0x40 },          /* Clear */
    { SDL_SCANCODE_ESCAPE, 1, 0x40 },     /* Mode  */
    { SDL_SCANCODE_BACKSPACE, 1, 0x80 },  /* Del   */
    { SDL_SCANCODE_RETURN, 6, 0x01 },     /* Enter */
    { SDL_SCANCODE_KP_ENTER, 6, 0x01 },
    { SDL_SCANCODE_F1, 1, 0x10 }, { SDL_SCANCODE_F2, 1, 0x08 },
    { SDL_SCANCODE_F3, 1, 0x04 }, { SDL_SCANCODE_F4, 1, 0x02 },
    { SDL_SCANCODE_F5, 1, 0x01 },
    { SDL_SCANCODE_M, 2, 0x40 }, { SDL_SCANCODE_S, 4, 0x80 },
    { SDL_SCANCODE_P, 4, 0x40 }, { SDL_SCANCODE_V, 5, 0x40 },
    { SDL_SCANCODE_0, 3, 0x01 }, { SDL_SCANCODE_1, 3, 0x02 }, { SDL_SCANCODE_4, 3, 0x04 },
    { SDL_SCANCODE_7, 3, 0x08 }, { SDL_SCANCODE_2, 4, 0x02 }, { SDL_SCANCODE_5, 4, 0x04 },
    { SDL_SCANCODE_8, 4, 0x08 }, { SDL_SCANCODE_3, 5, 0x02 }, { SDL_SCANCODE_6, 5, 0x04 },
    { SDL_SCANCODE_9, 5, 0x08 },
    { SDL_SCANCODE_KP_PLUS, 6, 0x02 }, { SDL_SCANCODE_KP_MINUS, 6, 0x04 },
    { SDL_SCANCODE_KP_MULTIPLY, 6, 0x08 }, { SDL_SCANCODE_KP_DIVIDE, 6, 0x10 },
    { SDL_SCANCODE_PERIOD, 4, 0x01 }, { SDL_SCANCODE_COMMA, 3, 0x10 },
};

static int quit_requested = 0;
static int quit_scans = 0;

void kb_Scan(void)
{
    if (ce_video_ready()) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit_requested = 1;
        }

        const Uint8 *ks = SDL_GetKeyboardState(NULL);
        for (int g = 0; g < 8; g++) kb_Data[g] = 0;
        for (size_t i = 0; i < sizeof keymap / sizeof keymap[0]; i++)
            if (ks[keymap[i].sc]) kb_Data[keymap[i].group] |= keymap[i].mask;

        ce_present_if_due();
    }

    if (quit_requested) {
        kb_Data[1] |= 0x40 | 0x20;
        if (++quit_scans > 180) { SDL_Quit(); exit(0); }
    }
}

uint8_t kb_ScanGroup(uint8_t row)
{
    kb_Scan();
    return (row >= 1 && row <= 7) ? (uint8_t)kb_Data[row] : 0;
}

uint8_t kb_AnyKey(void)
{
    kb_Scan();
    for (int g = 1; g < 8; g++) if (kb_Data[g]) return 1;
    return 0;
}

void kb_Reset(void) {}
void kb_SetMode(uint8_t mode) { (void)mode; }
void kb_DisableOnLatch(void) {}
void kb_ClearOnLatch(void) {}
bool kb_On(void) { return false; }
'@

    # Generate files from the embedded source.
    # include
    Set-Content `
        -LiteralPath (Join-Path $includeDir "fileioc.h") `
        -Value $fileiocH `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "graphx.h") `
        -Value $graphxH `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "keypadc.h") `
        -Value $keypadcH `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "tice.h") `
        -Value $ticeH `
        -Encoding utf8

    # src
    Set-Content `
        -LiteralPath (Join-Path $srcDir "ce_internal.h") `
        -Value $ce_internalH `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "fileioc.c") `
        -Value $fileiocC `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "graphx.c") `
        -Value $graphxC `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "keypadc.c") `
        -Value $keypadcC `
        -Encoding utf8

    # --- Makefiles ---
    # directory
    $makefileDir = Join-Path $InstallDir "makefiles"
    New-Item -ItemType Directory `
        -Path $makefileDir -Force | Out-Null
        
    # files
    $ceMakefile = @'
NAME = CNAME
DESCRIPTION = CDESC

TARGET = CTAR
SRCDIR = CSRCDIR
SRCS = CSRCFILES

CFLAGS = -Wall -Wextra -O2 -ICINCDIR
LIBS = graphx keypadc fileioc tice

BINDIR = CBINDIR/cal
OBJDIR = CBUILDDIR/cal

LTO = NO

include $(CEDEV)\meta\makefile.mk
'@

    $CMakeLists = @'
cmake_minimum_required(VERSION 3.13)

set(BUILD_NAME "CTAR")
set(PROJECT_TITLE "CNAME")

project(ce_project_desktop C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

set(SRC_DIR "${CMAKE_SOURCE_DIR}/CSRCDIR"
    CACHE PATH "Folder with the .c files"
)

if(WIN32)
    set(PLATFORM_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/win")
elseif(APPLE)
    set(PLATFORM_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/mac")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(PLATFORM_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/CBINDIR/lnx")
else()
    message(FATAL_ERROR "Unsupported target platform: ${CMAKE_SYSTEM_NAME}")
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}")

find_package(SDL2 REQUIRED)

add_library(ce_shim STATIC
    port_shim/src/graphx.c
    port_shim/src/keypadc.c
    port_shim/src/fileioc.c
)

target_compile_definitions(ce_shim PRIVATE
    CE_WINDOW_TITLE="${PROJECT_TITLE}"
)

target_include_directories(ce_shim PUBLIC
    port_shim/include
)

target_include_directories(ce_shim PRIVATE
    port_shim/src
)

set(INCLUDE_DIR "${CMAKE_SOURCE_DIR}/CINCDIR"
    CACHE PATH "Folder with the project headers"
)

set(MAIN_SOURCE "${SRC_DIR}/CSRCFILES")
if(NOT EXISTS "${MAIN_SOURCE}")
    message(FATAL_ERROR "Entry file not found: ${MAIN_SOURCE}")
endif()

file(GLOB_RECURSE GAME_SOURCES CONFIGURE_DEPENDS "${SRC_DIR}/*.c")
list(APPEND GAME_SOURCES "${MAIN_SOURCE}")
list(REMOVE_DUPLICATES GAME_SOURCES)

if(WIN32 AND EXISTS "${CMAKE_SOURCE_DIR}/resources/icon.ico")
    enable_language(RC)
endif()

if(WIN32)
    add_executable(${BUILD_NAME} WIN32 ${GAME_SOURCES})
elseif(APPLE)
    add_executable(${BUILD_NAME} MACOSX_BUNDLE ${GAME_SOURCES})
else()
    add_executable(${BUILD_NAME} ${GAME_SOURCES})
endif()

target_link_libraries(${BUILD_NAME} PRIVATE ce_shim)

target_include_directories(${BUILD_NAME} PRIVATE
    "${SRC_DIR}"
    "${INCLUDE_DIR}"
)

if(WIN32)
    set_target_properties(${BUILD_NAME} PROPERTIES
        OUTPUT_NAME "${BUILD_NAME}"
        SUFFIX ".exe"
        RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}"
    )

    if(EXISTS "${CMAKE_SOURCE_DIR}/resources/icon.ico")
        file(WRITE "${CMAKE_BINARY_DIR}/app.rc"
            "IDI_ICON1 ICON \"${CMAKE_SOURCE_DIR}/resources/icon.ico\"\n"
        )

        target_sources(${BUILD_NAME} PRIVATE
            "${CMAKE_BINARY_DIR}/app.rc"
        )
    endif()

elseif(APPLE)
    set_target_properties(${BUILD_NAME} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "${PROJECT_TITLE}"
        MACOSX_BUNDLE_GUI_IDENTIFIER "org.${BUILD_NAME}.game"
        MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0"
        OUTPUT_NAME "${BUILD_NAME}"
        RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}"
    )

elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set_target_properties(${BUILD_NAME} PROPERTIES
        OUTPUT_NAME "${BUILD_NAME}"
        SUFFIX ".elf"
        RUNTIME_OUTPUT_DIRECTORY "${PLATFORM_OUTPUT_DIR}"
    )
endif()

if(TARGET SDL2::SDL2)
    target_link_libraries(ce_shim PUBLIC SDL2::SDL2)
else()
    target_include_directories(ce_shim PUBLIC
        ${SDL2_INCLUDE_DIRS}
    )
    target_link_libraries(ce_shim PUBLIC
        ${SDL2_LIBRARIES}
    )
endif()

if(UNIX)
    target_link_libraries(ce_shim PUBLIC m)
endif()
'@
    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "CEMakefile.mk") `
        -Value $ceMakefile `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "CMakeLists.txt") `
        -Value $CMakeLists `
        -Encoding utf8

    # --- Python Helpers ---
    # directory
    $helperDir = Join-Path $InstallDir "python"
    New-Item -ItemType Directory `
        -Path $helperDir -Force | Out-Null

    # TODO: Add the python helper files -----------------------------------------------------------------------

    # files
    $compilespritefolder = @'
import sys
import os

def parse_sprite(path):
    with open(path, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    sprite = []
    for line in lines:
        sprite.append([int(v.strip()) for v in line.split(",")])

    height = len(sprite)
    width = len(sprite[0]) if height > 0 else 0

    return sprite, width, height

def write_header(sprites, h_path):
    with open(h_path, "w") as f:
        f.write(f"""
                
#pragma once
#include <graphx.h>
#include <stdint.h>

""")

        # Write sprite data and pointers inline
        for name, (sprite, w, h) in sprites.items():
            f.write(f"// {name} ({w}x{h})\n")
            f.write(f"static unsigned char {name}_data[] = {{\n")
            f.write(f"    {w}, {h},\n")

            for y, row in enumerate(sprite):
                f.write("    ")
                f.write(", ".join(str(px & 0xFF) for px in row))
                if y < len(sprite) - 1:
                    f.write(",")
                f.write("\n")

            f.write("};\n")
            f.write(f"static gfx_sprite_t *{name}_sprite = (gfx_sprite_t*){name}_data;\n\n")
            f.write(f"#define {name.upper()}_WIDTH {w}\n")
            f.write(f"#define {name.upper()}_HEIGHT {h}\n\n")

def main():
    if len(sys.argv) < 3:
        print("Usage: python compilespritefolder.py sprite_folder output.h")
        sys.exit(1)

    sprite_dir = sys.argv[1]
    output = sys.argv[2]

    # Create output directory if one was specified
    output_dir = os.path.dirname(output)

    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    sprites = {}

    for file in os.listdir(sprite_dir):
        if not file.endswith(".sprite"):
            continue

        name = os.path.splitext(file)[0]
        path = os.path.join(sprite_dir, file)

        sprite, w, h = parse_sprite(path)
        sprites[name] = (sprite, w, h)

        print(f"Loaded {name} ({w}x{h})")

    if not sprites:
        print("No .sprite files found.")
        sys.exit(1)

    write_header(sprites, output)

    print(f"\nGenerated {output} with {len(sprites)} sprites (header-only)")

if __name__ == "__main__":
    main()
'@

    $createspritefolder = @'
from PIL import Image
import sys
import os


def get_graphx_palette():
    """
    Generate the palette used by setup_xlibc_palette().

    Palette index:
        RRR GGG BB

    Red/green:
        3-bit -> 5-bit

    Blue:
        2-bit -> 5-bit

    The resulting 5-bit channels are expanded to 8-bit
    so they can be compared against Pillow RGB values.
    """
    palette = []

    for i in range(256):
        # Extract packed palette components
        r3 = (i >> 5) & 0x07
        g3 = (i >> 2) & 0x07
        b2 = i & 0x03

        # Match the C code exactly:
        #
        # r = (r << 2) | (r >> 1);
        # g = (g << 2) | (g >> 1);
        # b = (b << 3) | (b << 1) | (b >> 1);

        r5 = (r3 << 2) | (r3 >> 1)
        g5 = (g3 << 2) | (g3 >> 1)
        b5 = (b2 << 3) | (b2 << 1) | (b2 >> 1)

        # Convert 5-bit values to 8-bit RGB for Pillow.
        #
        # Use bit replication, matching the style of the
        # C conversion rather than simple multiplication.
        r8 = (r5 << 3) | (r5 >> 2)
        g8 = (g5 << 3) | (g5 >> 2)
        b8 = (b5 << 3) | (b5 >> 2)

        palette.append((r8, g8, b8))

    return palette


def find_closest_palette_index(r, g, b, palette):
    """Find the closest color in the TI-84 CE palette."""
    min_dist = float("inf")
    closest_idx = 0

    for idx, (pr, pg, pb) in enumerate(palette):
        dist = (
            (r - pr) ** 2 +
            (g - pg) ** 2 +
            (b - pb) ** 2
        )

        if dist < min_dist:
            min_dist = dist
            closest_idx = idx

    return closest_idx


def image_to_sprite(image_path, out_path, palette, width=None, height=None):
    """Convert one image to a .sprite file."""

    img = Image.open(image_path).convert("RGB")

    if width is not None and height is not None:
        img = img.resize((width, height), Image.NEAREST)

    w, h = img.size
    pixels = img.load()

    with open(out_path, "w") as f:
        for y in range(h):
            row = []

            for x in range(w):
                r, g, b = pixels[x, y]

                ti_col = find_closest_palette_index(
                    r, g, b, palette
                )

                row.append(str(ti_col))

            f.write(", ".join(row) + "\n")

    print(
        f"Converted {os.path.basename(image_path)} "
        f"→ {os.path.basename(out_path)} ({w}x{h})"
    )


def main():

    if len(sys.argv) < 3:
        print("Usage:")
        print(
            "  python createspritefolder.py "
            "input_folder output_folder [width height]"
        )
        sys.exit(1)

    input_folder = sys.argv[1]
    output_folder = sys.argv[2]

    # Optional resize dimensions
    width = None
    height = None

    if len(sys.argv) == 5:
        width = int(sys.argv[3])
        height = int(sys.argv[4])

    # Verify input folder
    if not os.path.isdir(input_folder):
        print(f"Error: Input folder does not exist: {input_folder}")
        sys.exit(1)

    # Create output folder
    os.makedirs(output_folder, exist_ok=True)

    # Generate the exact TI-84 CE palette
    palette = get_graphx_palette()

    image_extensions = {
        ".png",
        ".jpg",
        ".jpeg",
        ".bmp",
        ".gif"
    }

    converted = 0

    # Process every image in the folder
    for filename in os.listdir(input_folder):

        input_path = os.path.join(input_folder, filename)

        # Ignore directories
        if not os.path.isfile(input_path):
            continue

        extension = os.path.splitext(filename)[1].lower()

        # Ignore non-image files
        if extension not in image_extensions:
            continue

        # Remove extension
        name = os.path.splitext(filename)[0]

        # Create output filename
        output_path = os.path.join(
            output_folder,
            name + ".sprite"
        )

        try:
            image_to_sprite(
                input_path,
                output_path,
                palette,
                width,
                height
            )

            converted += 1

        except Exception as e:
            print(f"Failed to convert {filename}: {e}")

    print()
    print(f"Converted {converted} image(s).")
    print(f"Output folder: {output_folder}")


if __name__ == "__main__":
    main()
'@

    $generatetileset = @'
import re
import sys
from pathlib import Path

# Matches: static gfx_sprite_t *NAME_sprite = (gfx_sprite_t*)NAME_data;
SPRITE_RE = re.compile(
    r'static\s+gfx_sprite_t\s*\*\s*(\w+)_sprite\s*='
)


def extract_sprite_names(text: str) -> list[str]:
    """Return sprite base names in the order they appear in the file."""
    names = SPRITE_RE.findall(text)
    # de-dupe while preserving order, just in case
    seen = set()
    ordered = []
    for n in names:
        if n not in seen:
            seen.add(n)
            ordered.append(n)
    return ordered


def build_tileset_h(names: list[str], spritefile: str) -> str:
    lines = []

    lines.append("#ifndef TILESET_H")
    lines.append("#define TILESET_H")
    lines.append("")
    lines.append(f'#pragma once')
    lines.append(f'#include "../libs/tiles.h"')
    lines.append(f'#include "{spritefile.split(".")[0]}.h"')
    lines.append("")
    lines.append("Tile tileset[MAX_TILES];")
    lines.append("")
    lines.append("void loadTileset() {")
    lines.append("    tiles_init(tileset);")
    lines.append("")

    for i, name in enumerate(names):
        lines.append(f"    tiles_set(tileset, {i}, {name}_sprite);")

    lines.append("}")
    lines.append("")
    lines.append("#endif")
    lines.append("")
    lines.append("/* ")
    lines.append("const TILE_NAMES = [" + ",".join(f"'{n}'" for n in names) + "];")
    lines.append("*/")
    lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_tileset.py <sprites.h> [tileset.h]")
        sys.exit(1)

    src_path = Path(sys.argv[1])
    if len(sys.argv) >= 3:
        dst_path = Path(sys.argv[2])
    else:
        dst_path = src_path.with_name("tileset.h")

    text = src_path.read_text()
    names = extract_sprite_names(text)

    if not names:
        print("No sprites found (looking for 'static gfx_sprite_t *NAME_sprite = ...').")
        sys.exit(1)
    print(src_path.name)
    output = build_tileset_h(names, src_path.name)
    dst_path.write_text(output)

    print(f"Found {len(names)} sprites.")
    print(f"Wrote {dst_path}")


if __name__ == "__main__":
    main()
'@

    $spritetopngfolder = @'
from PIL import Image
import sys
import os


def get_ti84_palette():
    """
    Generates the exact palette used by setup_xlibc_palette().

    Palette index:
        RRR GGG BB

    Red/green:
        3-bit -> 5-bit

    Blue:
        2-bit -> 5-bit

    The 5-bit values are then expanded to 8-bit RGB
    for use by Pillow.
    """
    palette = []

    for i in range(256):
        # Extract RRRGGGBB
        r3 = (i >> 5) & 0x07
        g3 = (i >> 2) & 0x07
        b2 = i & 0x03

        # Match setup_xlibc_palette() exactly:
        #
        # r = (r << 2) | (r >> 1);
        # g = (g << 2) | (g >> 1);
        # b = (b << 3) | (b << 1) | (b >> 1);

        r5 = (r3 << 2) | (r3 >> 1)
        g5 = (g3 << 2) | (g3 >> 1)
        b5 = (b2 << 3) | (b2 << 1) | (b2 >> 1)

        # Expand 5-bit RGB to 8-bit RGB for Pillow.
        r8 = (r5 << 3) | (r5 >> 2)
        g8 = (g5 << 3) | (g5 >> 2)
        b8 = (b5 << 3) | (b5 >> 2)

        palette.extend((r8, g8, b8))

    return palette


def sprite_to_png(sprite_path, out_path, scale=1):
    try:
        with open(sprite_path, "r") as f:
            lines = [line.strip() for line in f if line.strip()]

        if not lines:
            print(
                f"Skipped {os.path.basename(sprite_path)}: "
                f"empty file"
            )
            return False

        # Convert text indices into rows
        rows = []

        for line in lines:
            row = [
                int(v.strip())
                for v in line.split(",")
                if v.strip()
            ]

            if row:
                rows.append(row)

        if not rows:
            print(
                f"Skipped {os.path.basename(sprite_path)}: "
                f"no pixel data"
            )
            return False

        # Make sure every row has the same width
        width = len(rows[0])

        for row in rows:
            if len(row) != width:
                print(
                    f"Skipped {os.path.basename(sprite_path)}: "
                    f"inconsistent row widths"
                )
                return False

        height = len(rows)

        # Flatten pixel data
        data = []

        for row in rows:
            data.extend(row)

        # Validate palette indices
        for index in data:
            if index < 0 or index > 255:
                print(
                    f"Skipped {os.path.basename(sprite_path)}: "
                    f"invalid palette index {index}"
                )
                return False

        # Create palette-based image
        img = Image.new("P", (width, height))

        # Load exact TI-84 CE palette
        img.putpalette(get_ti84_palette())

        # Put raw palette indices into image
        img.putdata(data)

        # Convert using the palette
        img = img.convert("RGB")

        # Optional scaling
        if scale > 1:
            img = img.resize(
                (width * scale, height * scale),
                Image.NEAREST
            )

        img.save(out_path)

        print(
            f"Converted {os.path.basename(sprite_path)} "
            f"→ {os.path.basename(out_path)} "
            f"({width}x{height})"
        )

        return True

    except Exception as e:
        print(
            f"Error processing "
            f"{os.path.basename(sprite_path)}: {e}"
        )
        return False


def main():
    if len(sys.argv) < 3:
        print(
            "Usage: python spritetopngfolder.py "
            "input_folder output_folder [scale]"
        )
        sys.exit(1)

    input_folder = sys.argv[1]
    output_folder = sys.argv[2]

    # Optional scale
    scale = int(sys.argv[3]) if len(sys.argv) >= 4 else 1

    # Validate scale
    if scale < 1:
        print("Error: scale must be at least 1.")
        sys.exit(1)

    # Check input folder
    if not os.path.isdir(input_folder):
        print(
            f"Error: input folder does not exist: "
            f"{input_folder}"
        )
        sys.exit(1)

    # Create output folder
    os.makedirs(output_folder, exist_ok=True)

    converted = 0
    skipped = 0

    # Process every file in the folder
    for filename in os.listdir(input_folder):

        input_path = os.path.join(input_folder, filename)

        # Ignore directories
        if not os.path.isfile(input_path):
            continue

        # Only process .sprite files
        if not filename.lower().endswith(".sprite"):
            continue

        # Change .sprite -> .png
        name = os.path.splitext(filename)[0]

        output_path = os.path.join(
            output_folder,
            name + ".png"
        )

        if sprite_to_png(input_path, output_path, scale):
            converted += 1
        else:
            skipped += 1

    print()
    print(f"Converted: {converted}")
    print(f"Skipped:   {skipped}")
    print(f"Output:    {output_folder}")


if __name__ == "__main__":
    main()
'@

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $helperDir "compilespritefolder.py") `
        -Value $compilespritefolder `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "createspritefolder.py") `
        -Value $createspritefolder `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "generatetileset.py") `
        -Value $generatetileset `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "spritetopngfolder.py") `
        -Value $spritetopngfolder `
        -Encoding utf8
    
    # === Finalize Instilation ===

    # Make profile load script
    $cbuildScript = Join-Path $HOME "cbuild\cbuild.ps1"
    . $cbuildScript
    $profileLine = "`n. `"$cbuildScript`""
    Add-Content -Path $PROFILE -Value $profileLine

    # Remove self (installer)
    if (-not [string]::Equals(
        $sourceFullPath,
        $targetFullPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Remove-Item -Path $PSCommandPath -Force
    }
}

function Add-CBuildUserPath {
    param([Parameter(Mandatory)][string]$Dir)

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @($userPath -split ';' | Where-Object { $_ })

    if ($parts -notcontains $Dir) {
        [Environment]::SetEnvironmentVariable("Path", (($parts + $Dir) -join ';'), "User")
    }
    if (($env:Path -split ';') -notcontains $Dir) {
        $env:Path = "$Dir;$env:Path"
    }
}

function Install-CBuildCalculator {
    Write-Host ">>> Installing Calculator dependencies..."


    $cedev = Join-Path $HOME "CEdev"

    # 1. Download the toolchain (latest GitHub release)
    if (-not (Test-Path (Join-Path $cedev "bin"))) {
        Write-Host "Downloading CE toolchain..."
        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/CE-Programming/toolchain/releases/latest" `
            -Headers @{ "User-Agent" = "cbuild" }

        $asset = $release.assets |
            Where-Object { $_.name -like "CEdev-Windows*.zip" } |
            Select-Object -First 1
        if (-not $asset) { throw "Could not find a Windows CEdev asset in the latest release." }

        $zip = Join-Path $env:TEMP $asset.name
        $tmp = Join-Path $env:TEMP "cedev_extract"
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

        # The zip normally contains a top-level CEdev folder; handle either layout
        $root = if (Test-Path (Join-Path $tmp "bin")) { $tmp }
                else { (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName }

        if (Test-Path $cedev) { Remove-Item $cedev -Recurse -Force }
        Move-Item -LiteralPath $root -Destination $cedev
        Remove-Item $zip, $tmp -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "CE toolchain already present."
    }

    # 2. Environment
    [Environment]::SetEnvironmentVariable("CEDEV", $cedev, "User")
    $env:CEDEV = $cedev
    Add-CBuildUserPath (Join-Path $cedev "bin")
}

function Install-CBuildWindows {
    Write-Host ">>> Installing Windows dependencies..."

    $msys = "C:\msys64"

    # 1. MSYS2
    if (-not (Test-Path (Join-Path $msys "usr\bin\bash.exe"))) {
        & winget install MSYS2.MSYS2 --accept-package-agreements --accept-source-agreements
        if (-not (Test-Path (Join-Path $msys "usr\bin\bash.exe"))) {
            throw "MSYS2 not found at $msys after install. If it went elsewhere, adjust `$msys."
        }
    }

    # 2. Toolchain + SDL2 via pacman
    $pkgs = "mingw-w64-ucrt-x86_64-gcc " +
            "mingw-w64-ucrt-x86_64-cmake " +
            "mingw-w64-ucrt-x86_64-ninja " +
            "mingw-w64-ucrt-x86_64-SDL2"

    & (Join-Path $msys "usr\bin\bash.exe") -lc "pacman -Syu --noconfirm"
    & (Join-Path $msys "usr\bin\bash.exe") -lc "pacman -S --needed --noconfirm $pkgs"
    if ($LASTEXITCODE -ne 0) { throw "pacman failed to install Windows build dependencies." }

    # 3. PATH (gcc, cmake, ninja, and SDL2.dll all live here)
    Add-CBuildUserPath (Join-Path $msys "ucrt64\bin")
}

function Install-CBuildLinux {
    Write-Host ">>> Installing Linux dependencies..."

    # 1. WSL itself
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "wsl.exe not found. Enable WSL on this Windows version first."
    }

    # wsl output is UTF-16, so strip NULs before comparing
    $distros = (& wsl.exe -l -q 2>$null) -join "`n"
    $distros = $distros -replace "`0", ""

    if ([string]::IsNullOrWhiteSpace($distros)) {
        Write-Host "Installing WSL2 with Ubuntu (may require admin + a reboot)..."
        & wsl.exe --install -d Ubuntu
        Write-Host "`nReboot if prompted, finish the Ubuntu first-run setup,"
        Write-Host "then run 'cbuild install -lnx' again to install the packages." `
            -ForegroundColor Yellow
        return
    }

    # 2. Packages inside the default distro
    & wsl.exe -u root -- bash -c `
        "apt-get update && apt-get install -y build-essential cmake ninja-build libsdl2-dev"
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Linux build dependencies in WSL." }
}