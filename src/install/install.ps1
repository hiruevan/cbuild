function Install-cbuild() {
    param (
        [bool]$force,
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx,
        [bool]$runWeb,
        [string[]]$lnxArchs = @("x86_64"),

        [bool]$runGC
    )
    if ($all) {
        # Get build config
        $cfg = Read-CBuildConfig
        if ($cfg.PLATFORMS -contains "cal") {
            $runCal = $true
        }
        if ($cfg.PLATFORMS -contains "win") {
            $runWin = $true
        }
        if ($cfg.PLATFORMS -contains "webp") {
            $runWeb = $true
        }

        if ($cfg.PLATFORMS -contains "gc") {
            $RunGC = $true
        }

        $lnxArchs = @()
        if ($cfg.PLATFORMS -contains "lnx") {
            $runLnx = $true
            $lnxArchs = @("x86_64")
        }
        if ($cfg.PLATFORMS -contains "lnx-x86_64") {
            $runLnx = $true
            $lnxArchs = @("x86_64")
        }
        if ($cfg.PLATFORMS -contains "lnx-aarch64") {
            $runLnx = $true
            $lnxArchs += "aarch64"
        }
        if ($cfg.PLATFORMS -contains "lnx-armhf") {
            $runLnx = $true
            $lnxArchs += "armhf"
        }
    }

    # Install basic cbuild profile
    Install-cbuilddir -force $force -runOthers ($runCal -or $runWin -or $runLnx -or $runWeb -or $runGc)

    # Install calculator profile
    if ($runCal) {
        Write-Host ">>> Installing calculator dependencies..."
        Install-cbuildCalculator
    }

    # Install windows profile
    if ($runWin) {
        Write-Host ">>> Installing Windows dependencies..."
        Install-cbuildWindows
    }

    # Install linux profile
    if ($runLnx) {
        Write-Host ">>> Installing Linux dependencies..."
        Install-cbuildLinux -lnxArchs $lnxArchs
    }

    # Install Webp profile
    if ($runWeb) {
        Write-Host ">>> Installing Webpage dependencies..."
        Install-CBuildWebp
    }

    # Install GameCube profile
    if ($runGC) {
        Write-Host ">>> Installing GameCube dependencies..."
        Install-CBuildGameCube
    }

    Write-Host "cbuild installed successfully." -ForegroundColor Green
}

function Install-cbuilddir() {
    param (
        [bool]$force,
        [bool]$runOthers
    )

    Write-Host "`n>>> Preparing cbuild installation..."
    $ErrorActionPreference = "Stop"
    $installDir = Join-Path $HOME "cbuild"

    if ((Test-Path -LiteralPath (Join-Path $installDir "requirements.txt")) -and -not $force) {
        if (-not $runOthers) {
            Write-Host "cbuild is already installed! Use -force to reinstall."

            Install-CBuildProfile
        }

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

    # Remove Mark of the Web from both scripts.
    Unblock-CBuildScript -Path $sourceFullPath
    Unblock-CBuildScript -Path $targetFullPath

    # Install and validate Python dependencies.
    $script:CBuildPython = Install-CBuildPython

    # === Install all the relevant cbuild files ===
    Write-Host ">>> Installing cbuild..."
    Set-Content `
        -LiteralPath (Join-Path $installDir "help.txt") `
        -Value @'
<help.txt>
'@
    Set-Content `
        -LiteralPath (Join-Path $installDir "requirements.txt") `
        -Value @'
<requirements.txt>
'@ `
        -Encoding utf8
    # ------ SHIMS ------

    # --- shim (shared layout: shim\include, common, calc, desk, gc, web) ---
    $shimDir = Join-Path $InstallDir "shim"
    New-Item -ItemType Directory `
        -Path $shimDir -Force | Out-Null

    # --- shim/include (desktop + GameCube API headers) ---
    $includeDir = Join-Path $shimDir "include"
    New-Item -ItemType Directory `
        -Path $includeDir -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $includeDir "graphics.h") `
        -Value @'
<shim/include/graphics.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "files.h") `
        -Value @'
<shim/include/files.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "random.h") `
        -Value @'
<shim/include/random.h>
'@ `
        -Encoding utf8

    # --- shim/common (header-only helpers shared by every platform) ---
    $commonDir = Join-Path $shimDir "common"
    New-Item -ItemType Directory `
        -Path $commonDir -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $commonDir "graphics_common.h") `
        -Value @'
<shim/common/graphics_common.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $commonDir "random_common.h") `
        -Value @'
<shim/common/random_common.h>
'@ `
        -Encoding utf8

    # --- shim/calc (TI-84 CE wrappers around CEdev) ---
    $calcDir = Join-Path $shimDir "calc"
    New-Item -ItemType Directory `
        -Path $calcDir -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $calcDir "graphics.h") `
        -Value @'
<shim/calc/graphics.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $calcDir "files.h") `
        -Value @'
<shim/calc/files.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $calcDir "random.h") `
        -Value @'
<shim/calc/random.h>
'@ `
        -Encoding utf8

    # --- shim/desk (Windows / Linux / Webpage) ---
    $deskDir = Join-Path $shimDir "desk"
    New-Item -ItemType Directory `
        -Path $deskDir -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $deskDir "ce_internal.h") `
        -Value @'
<shim/desk/ce_internal.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $deskDir "files.c") `
        -Value @'
<shim/desk/files.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $deskDir "graphics.c") `
        -Value @'
<shim/desk/graphics.c>
'@ `
        -Encoding utf8

    # --- shim/gc (GameCube) ---
    $gcDir = Join-Path $shimDir "gc"
    New-Item -ItemType Directory `
        -Path $gcDir -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $gcDir "SDL.h") `
        -Value @'
<shim/gc/SDL.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $gcDir "files.c") `
        -Value @'
<shim/gc/files.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $gcDir "graphics.c") `
        -Value @'
<shim/gc/graphics.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $gcDir "sdl_compat.c") `
        -Value @'
<shim/gc/sdl_compat.c>
'@ `
        -Encoding utf8

    # --- shim/web (Webpage shell) ---
    $webDir = Join-Path $shimDir "web"
    New-Item -ItemType Directory `
        -Path $webDir -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $webDir "shell.html") `
        -Value @'
<shim/web/shell.html>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $webDir "style.css") `
        -Value @'
<shim/web/style.css>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $webDir "module.js") `
        -Value @'
<shim/web/module.js>
'@ `
        -Encoding utf8

    # --- Custom Toolchains ---
    # directory
    $makefileDir = Join-Path $InstallDir "toolchains"
    New-Item -ItemType Directory `
        -Path $makefileDir -Force | Out-Null

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "toolchain-ti84.mk") `
        -Value @'
<toolchains/toolchain-ti84.mk>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "toolchain-desk.cmake") `
        -Value @'
<toolchains/toolchain-desk.cmake>
'@ `
        -Encoding utf8
            Set-Content `
        -LiteralPath (Join-Path $makefileDir "toolchain-aarch64.cmake") `
        -Value @'
<toolchains/toolchain-aarch64.cmake>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "toolchain-armhf.cmake") `
        -Value @'
<toolchains/toolchain-armhf.cmake>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "toolchain-gc.cmake") `
        -Value @'
<toolchains/toolchain-gc.cmake>
'@ `
        -Encoding utf8

    # --- Python Helpers ---
    # directory
    $helperDir = Join-Path $InstallDir "python"
    New-Item -ItemType Directory `
        -Path $helperDir -Force | Out-Null

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $helperDir "generationhelper.py") `
        -Value @'
<python/generationhelper.py>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "compilespritefolder.py") `
        -Value @'
<python/compilespritefolder.py>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "generateinputs.py") `
        -Value @'
<python/generateinputs.py>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "createspritefolder.py") `
        -Value @'
<python/createspritefolder.py>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "generatetileset.py") `
        -Value @'
<python/generatetileset.py>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $helperDir "spritetopngfolder.py") `
        -Value @'
<python/spritetopngfolder.py>
'@ `
        -Encoding utf8

    # --- Python-used C Templates (Inputs) ---
     # directory
    $templateDir = Join-Path $InstallDir "inputs"
    New-Item -ItemType Directory `
        -Path $templateDir -Force | Out-Null

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $templateDir "input.h") `
        -Value @'
<inputs/input.h>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "input.c") `
        -Value @'
<inputs/input.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "gamepad.c") `
        -Value @'
<inputs/gamepad.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_common.c") `
        -Value @'
<inputs/prompt_common.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_calculator.c") `
        -Value @'
<inputs/prompt_calculator.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_keyboard.c") `
        -Value @'
<inputs/prompt_keyboard.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_gamepad.c") `
        -Value @'
<inputs/prompt_gamepad.c>
'@ `
    -Encoding utf8

    # === Finalize Installation ===

    Install-CBuildProfile

    # Remove original installer if running from another location.
    if (-not [string]::Equals(
        $sourceFullPath,
        $targetFullPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        Remove-Item -LiteralPath $PSCommandPath -Force `
            -ErrorAction SilentlyContinue
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
    Write-Host "`n>>> Installing Calculator dependencies..."


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
    Write-Host "`n>>> Installing Windows dependencies..."

    $msys = "C:\msys64"

    # 1. MSYS2
    $bash = Join-Path $msys "usr\bin\bash.exe"
    if (-not (Test-Path $bash)) {
        & winget install MSYS2.MSYS2 --accept-package-agreements --accept-source-agreements

        if (-not (Test-Path $bash)) {
            Write-Warning "winget did not place MSYS2 at $msys (it may still list it as installed). Retrying with --force..."
            & winget install MSYS2.MSYS2 --force --accept-package-agreements --accept-source-agreements
        }
        if (-not (Test-Path $bash)) {
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
    param (
        [string[]]$lnxArchs
    )
    Write-Host "`n>>> Installing Linux dependencies..."

    # 1. WSL itself
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "wsl.exe not found. Enable WSL on this Windows version first."
    }

    # wsl output is UTF-16, so strip NULs before comparing
    $distros = (& wsl.exe -l -q 2>$null) -join ""
    $distros = $distros -replace "`0", ""

    if ([string]::IsNullOrWhiteSpace($distros)) {
        Write-Host "Installing WSL2 with Ubuntu (may require admin + a reboot)..."
        Write-Host "If a wsl terminal opens, enter 'exit' to continue"
        & wsl.exe --install -d Ubuntu-22.04
        & wsl.exe --set-default Ubuntu-22.04
        Write-Host "Reboot if prompted, finish the Ubuntu first-run setup,"
        Write-Host "then run 'cbuild install -lnx' again to install the packages." `
            -ForegroundColor Yellow
        return
    }

    # 2. Packages inside the default distro
    & wsl.exe -u root -- bash -c `
        "apt-get update && apt-get install -y build-essential cmake ninja-build libsdl2-dev"
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Linux build dependencies in WSL." }

    # 3. Cross-compile architectures (anything with a toolchain file)
    $cross = @($lnxArchs | Where-Object { $script:CBuildLinuxArchs[$_].Toolchain })
    if ($cross.Count -gt 0) {
        $entries = @($cross | ForEach-Object { $script:CBuildLinuxArchs[$_] })
        $archCsv = ($entries | ForEach-Object { $_.DebArch }) -join ","
        $pkgCsv  = ($entries | ForEach-Object { $_.Compiler; "libsdl2-dev:$($_.DebArch)" }) -join ","

        $crossScript = @'
set -e
ARCHS="${1//,/ }"
PKGS="${2//,/ }"
. /etc/os-release

# Restrict the normal mirrors to amd64 (they have no ARM packages)
SRC=/etc/apt/sources.list.d/ubuntu.sources
if [ -f "$SRC" ]; then
  grep -q '^Architectures:' "$SRC" || sed -i '/^Types:/a Architectures: amd64' "$SRC"
else
  sed -i -E '/^deb /{/\[arch=/!s/^deb /deb [arch=amd64] /}' /etc/apt/sources.list
fi

# ARM packages come from the ports mirror
cat > /etc/apt/sources.list.d/cbuild-ports.sources <<EOF
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports
Suites: $VERSION_CODENAME $VERSION_CODENAME-updates $VERSION_CODENAME-security
Components: main universe
Architectures: $ARCHS
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

for a in $ARCHS; do dpkg --add-architecture "$a"; done
apt-get update
apt-get install -y $PKGS
# end
'@

        Write-Host ">>> Installing cross-compile toolchains ($archCsv)..."
        ($crossScript -replace "`r", "") | & wsl.exe -u root -- bash -s -- $archCsv $pkgCsv
        if ($LASTEXITCODE -ne 0) { throw "Failed to install cross-compile dependencies in WSL." }
    }
}

function Install-CBuildWebp() {
    # 1. WSL itself
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "wsl.exe not found. Enable WSL on this Windows version first."
    }

    # wsl output is UTF-16, so strip NULs before comparing
    $distros = (& wsl.exe -l -q 2>$null) -join ""
    $distros = $distros -replace "`0", ""

    if ([string]::IsNullOrWhiteSpace($distros)) {
        Write-Host "Installing WSL2 with Ubuntu (may require admin + a reboot)..."
        Write-Host "If a wsl terminal opens, enter 'exit' to continue"
        & wsl.exe --install -d Ubuntu-22.04
        & wsl.exe --set-default Ubuntu-22.04
        Write-Host "Reboot if prompted, finish the Ubuntu first-run setup,"
        Write-Host "then run 'cbuild install -webp' again to install the packages." `
            -ForegroundColor Yellow
        return
    }

    #  2. apt packages
    & wsl.exe -u root -- bash -c "apt-get update && apt-get install -y git python3 cmake ninja-build xz-utils bzip2 ca-certificates"
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Emscripten prerequisites in WSL." }

    # 3. emsdk install
    $emsdkScript = @'
set -e
cd "$HOME"
if [ -d emsdk ]; then
  git -C emsdk pull
else
  git clone https://github.com/emscripten-core/emsdk.git
fi
cd emsdk
if [ ! -x upstream/emscripten/emcc ]; then
  ./emsdk install latest
  ./emsdk activate latest
fi
# end
'@

    ($emsdkScript -replace "`r", "") | & wsl.exe -- bash -s
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Emscripten in WSL." }

    # Final check
    & wsl.exe -- bash -lc 'source ~/emsdk/emsdk_env.sh >/dev/null 2>&1 && emcc --version'
    if ($LASTEXITCODE -ne 0) { throw "emcc is not working after install." }
}



function Install-CBuildGameCube {
    $image = "devkitpro/devkitppc:20261102"

    # --------------------------------------------------
    # 1. Check for Docker
    # --------------------------------------------------

    $docker = Get-Command docker -ErrorAction SilentlyContinue

    if (-not $docker) {
        Write-Host "Docker was not found. Installing Docker Desktop..."

        # Check for Windows Package Manager
        $winget = Get-Command winget -ErrorAction SilentlyContinue

        if (-not $winget) {
            throw @"
Windows Package Manager (winget) was not found.

Install Microsoft's App Installer:
https://aka.ms/getwinget

Then restart PowerShell and run:
    cbuild install -gc
"@
        }

        # Install Docker Desktop
        & winget install `
            --exact `
            --id Docker.DockerDesktop `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements

        if ($LASTEXITCODE -ne 0) {
            throw "Docker Desktop installation failed (exit code $LASTEXITCODE)."
        }

        Write-Host "Docker Desktop installation completed."
    }
    else {
        Write-Host "Docker is already installed."
    }

    # --------------------------------------------------
    # 2. Refresh PATH
    # --------------------------------------------------

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = "$machinePath;$userPath"

    # Check common Docker CLI locations
    $dockerPaths = @(
        "$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe",
        "$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe"
    )

    $docker = Get-Command docker -ErrorAction SilentlyContinue

    if (-not $docker) {
        foreach ($path in $dockerPaths) {
            if (Test-Path -LiteralPath $path) {
                $env:Path = "$(Split-Path $path -Parent);$env:Path"
                break
            }
        }
    }

    $docker = Get-Command docker -ErrorAction SilentlyContinue

    if (-not $docker) {
        throw @"
Docker Desktop was installed, but docker.exe could not be located.

Restart PowerShell and run:
    cbuild install -gc
"@
    }

    # --------------------------------------------------
    # 3. Start Docker Desktop
    # --------------------------------------------------

    Write-Host "`nChecking Docker Desktop..."

    $desktopPaths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe"
    )

    $desktop = $desktopPaths |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if ($desktop) {
        $running = Get-Process -Name "Docker Desktop" `
            -ErrorAction SilentlyContinue

        if (-not $running) {
            Write-Host "Starting Docker Desktop..."
            Start-Process -FilePath $desktop
        }
    }

    # --------------------------------------------------
    # 4. Wait for Docker engine
    # --------------------------------------------------

    Write-Host "Waiting for Docker engine..."

    $ready = $false

    for ($i = 0; $i -lt 36; $i++) {
        & docker info --format '{{.ServerVersion}}' 2>$null |
            Out-Null

        if ($LASTEXITCODE -eq 0) {
            $ready = $true
            break
        }

        Start-Sleep -Seconds 5
    }

    if (-not $ready) {
        throw @"
Docker Desktop is installed, but its engine did not become ready.

Open Docker Desktop manually, accept its first-run agreement
if prompted, and wait for the engine to start.

Then run:
    cbuild install -gc
"@
    }

    Write-Host "Docker engine is ready." -ForegroundColor Green

    # --------------------------------------------------
    # 5. Pull devkitPro image
    # --------------------------------------------------

    Write-Host "`nPulling devkitPro GameCube toolchain..."
    Write-Host "Image: $image"

    & docker pull $image

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download the devkitPro Docker image."
    }

    # --------------------------------------------------
    # 6. Verify toolchain
    # --------------------------------------------------

    Write-Host "`nVerifying GameCube toolchain..."

    & docker run --rm `
        --entrypoint bash `
        $image `
        -c 'export PATH="$DEVKITPPC/bin:$PATH"; set -e; command -v powerpc-eabi-gcc; powerpc-eabi-gcc --version; test -f "$DEVKITPRO/cmake/GameCube.cmake"; test -d "$DEVKITPRO/libogc/include"; cmake --version; ninja --version'

    if ($LASTEXITCODE -ne 0) {
        throw "The devkitPro Docker image failed toolchain verification."
    }
}
