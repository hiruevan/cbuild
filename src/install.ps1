function Install-cbuild() {
    param (
        [bool]$force,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx
    )
    # Install basic cbuild profile
    Install-cbuilddir -force $forceRun -runOthers ($runCal -or $runWin -or $runLnx)

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
        Install-cbuildLinux
    }

    Write-Host "`ncbuild installed successfully." -ForegroundColor Green
}

function Install-cbuilddir() {
    param (
        [bool]$force,
        [bool]$runOthers
    )

    Write-Host ">>> Preparing cbuild installation..."
    $installDir = Join-Path $HOME "cbuild"

    if ((Test-Path -LiteralPath (Join-Path $installDir "requirements.txt")) -and -not $force) {
        if (-not $runOthers) {
            Write-Host "cbuild is already installed! Use -force to reinstall."
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

    # Install python
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "[Notice] Python is required to use cbuild. `n>>> Installing python..."
        & winget install Python.Python.3.11 --accept-package-agreements
    }

    # Update pip
    & python -m pip install --upgrade pip

    # Install pillow
    & python -m pip install --quiet pillow
    if ($LASTEXITCODE -ne 0) { Write-Warning "Pillow install failed." }

    # === Install all the relevant cbuild files ===
    Write-Host ">>> Installing cbuild..."
    Set-Content `
        -LiteralPath (Join-Path $installDir "requirements.txt") `
        -Value @'
<requirements.txt>
'@ `
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

    # Generate files from the embedded source.
    # include
    Set-Content `
        -LiteralPath (Join-Path $includeDir "fileioc.h") `
        -Value @'
<port_shim/include/fileioc.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "graphx.h") `
        -Value @'
<port_shim/include/graphx.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "keypadc.h") `
        -Value @'
<port_shim/include/keypadc.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $includeDir "tice.h") `
        -Value @'
<port_shim/include/tice.h>
'@ `
        -Encoding utf8

    # src
    Set-Content `
        -LiteralPath (Join-Path $srcDir "ce_internal.h") `
        -Value @'
<port_shim/src/ce_internal.h>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "fileioc.c") `
        -Value @'
<port_shim/src/fileioc.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "graphx.c") `
        -Value @'
<port_shim/src/graphx.c>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $srcDir "keypadc.c") `
        -Value @'
<port_shim/src/keypadc.c>
'@ `
        -Encoding utf8

    # --- Makefiles ---
    # directory
    $makefileDir = Join-Path $InstallDir "makefiles"
    New-Item -ItemType Directory `
        -Path $makefileDir -Force | Out-Null

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "CEMakefile.mk") `
        -Value @'
<makefiles/CEMakefile.mk>
'@ `
        -Encoding utf8
    Set-Content `
        -LiteralPath (Join-Path $makefileDir "CMakeLists.txt") `
        -Value @'
<makefiles/CMakeLists.txt>
'@ `
        -Encoding utf8

    # --- Python Helpers ---
    # directory
    $helperDir = Join-Path $InstallDir "python"
    New-Item -ItemType Directory `
        -Path $helperDir -Force | Out-Null

    # Generate files from the embedded source.
    Set-Content `
        -LiteralPath (Join-Path $helperDir "compilespritefolder.py") `
        -Value @'
<python/compilespritefolder.py>
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