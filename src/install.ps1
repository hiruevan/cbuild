function Install-cbuild() {
    param (
        [bool]$force,
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx,
        [string[]]$lnxArchs = @("x86_64")
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
    Install-cbuilddir -force $force -runOthers ($runCal -or $runWin -or $runLnx)

    # Install calculator profile
    if ($runCal) {
        Install-cbuildCalculator
    }

    # Install windows profile
    if ($runWin) {
        Install-cbuildWindows
    }

    # Install linux profile
    if ($runLnx) {
        Install-cbuildLinux -lnxArchs $lnxArchs
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

    # --- desk_shim ---
    # directories
    $shimDir = Join-Path $InstallDir "desk_shim"
    New-Item -ItemType Directory `
        -Path $shimDir -Force | Out-Null
    $includeDir = Join-Path $shimDir "include"
    New-Item -ItemType Directory `
        -Path $includeDir -Force | Out-Null
    $srcDir = Join-Path $shimDir "src"
    New-Item -ItemType Directory `
        -Path $srcDir -Force | Out-Null

    # Generate files from the embedded source.
    # include
    Set-Content `
        -LiteralPath (Join-Path $includeDir "fileioc.h") `
        -Value @'
<desk_shim/include/fileioc.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "graphx.h") `
        -Value @'
<desk_shim/include/graphx.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "keypadc.h") `
        -Value @'
<desk_shim/include/keypadc.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "tice.h") `
        -Value @'
<desk_shim/include/tice.h>
'@ `
        -Encoding utf8

    # src
    Set-Content `
        -LiteralPath (Join-Path $srcDir "ce_internal.h") `
        -Value @'
<desk_shim/src/ce_internal.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "fileioc.c") `
        -Value @'
<desk_shim/src/fileioc.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "graphx.c") `
        -Value @'
<desk_shim/src/graphx.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "keypadc.c") `
        -Value @'
<desk_shim/src/keypadc.c>
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

    # --- Python-used C Templates ---
     # directory
    $templateDir = Join-Path $InstallDir "templates"
    New-Item -ItemType Directory `
        -Path $templateDir -Force | Out-Null

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $templateDir "input.h") `
        -Value @'
<templates/input.h>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "input.c") `
        -Value @'
<templates/input.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "gamepad.c") `
        -Value @'
<templates/gamepad.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_common.c") `
        -Value @'
<templates/prompt_common.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_calculator.c") `
        -Value @'
<templates/prompt_calculator.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_keyboard.c") `
        -Value @'
<templates/prompt_keyboard.c>
'@ `
    -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $templateDir "prompt_gamepad.c") `
        -Value @'
<templates/prompt_gamepad.c>
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