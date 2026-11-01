$script:CBuildLinuxArchs = @{
    x86_64  = @{ Dir = "lnx-x86_64";  Toolchain = $null }
    aarch64 = @{ Dir = "lnx-aarch64"; Toolchain = "toolchain-aarch64.cmake"
                 DebArch = "arm64";   Compiler  = "gcc-aarch64-linux-gnu" }
    armhf   = @{ Dir = "lnx-armhf";   Toolchain = "toolchain-armhf.cmake"
                 DebArch = "armhf";   Compiler  = "gcc-arm-linux-gnueabihf" }
}

function Invoke-cbuildmake() {
    param (
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx,
        [string[]]$lnxArchs = @("x86_64")
    )
    # Get build config
    $cfg = Read-CBuildConfig

    # Build calculator
    if ($runCal) {
        Write-Host "`n>>> Preparing Calculator toolchain..."
        if (-not $env:CEDEV) {
            $env:CEDEV = [Environment]::GetEnvironmentVariable("CEDEV", "User")
        }
        if (-not $env:CEDEV) { $env:CEDEV = Join-Path $HOME "CEdev" }
        if (-not (Test-Path (Join-Path $env:CEDEV "meta\makefile.mk"))) {
            throw "CE toolchain not found at $env:CEDEV. Run 'cbuild install -cal'."
        }
        $env:CEDEV = $env:CEDEV.Replace('\', '/')
        $env:Path = "$(Join-Path $env:CEDEV 'bin');$env:Path"
        Write-Host ">>> Configuring calculator build..."
        New-CBuildFile (Join-Path $script:CBuildMakefileDir "CEMakefile.mk") "Makefile" $cfg

        Write-Host ">>> Building calculator target..."
        & make

        # Clean up
        Remove-Item -Path (Join-Path $PWD.Path "Makefile") -Force

        if ($LASTEXITCODE -ne 0) {
            throw "Calculator build failed with exit code $LASTEXITCODE."
        }
    }

    # Build windows
    if ($runWin) {
        Write-Host "`n>>> Configuring Windows build..."
        
        New-CBuildFile (Join-Path $script:CBuildMakefileDir "CMakeLists.txt") "CMakeLists.txt" $cfg
        $buildDir = Join-Path (Join-Path $PWD $cfg.BUILD) "win"

        & cmake -S . -B $buildDir -G Ninja `
            -DCMAKE_BUILD_TYPE=Release

        Write-Host ">>> Building Windows target..."
        & cmake --build $buildDir

        # Clean up
        Remove-Item -Path (Join-Path $PWD.Path "CMakeLists.txt") -Force

        if ($LASTEXITCODE -ne 0) {
            throw "Windows build failed with exit code $LASTEXITCODE."
        }
    }

    # Build linux
    if ($runLnx) {
        $winShim   = Join-Path $HOME "cbuild/port_shim"
        $linuxShim = (& wsl.exe wslpath -a ($winShim.Replace('\', '/'))).Trim()

        # The template is identical for every architecture, so generate it once
        New-CBuildFile (Join-Path $script:CBuildMakefileDir "CMakeLists.txt") "CMakeLists.txt" $cfg -Shim $linuxShim

        try {
            foreach ($arch in $lnxArchs) {
                $entry    = $script:CBuildLinuxArchs[$arch]
                $buildDir = "$($cfg.BUILD)/$($entry.Dir)"

                if ($entry.Toolchain) {
                    & wsl.exe dpkg -s $entry.Compiler 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        throw "Cross compiler for '$arch' is not installed. Run 'cbuild install -lnx $arch'."
                    }
                }

                Write-Host "`n>>> Configuring Linux ($arch) build..."
                $cmakeArgs = @(
                    "-S", ".", "-B", $buildDir, "-G", "Ninja",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DCBUILD_LNX_DIR=$($entry.Dir)"
                )
                if ($entry.Toolchain) {
                    $tcWin   = Join-Path $script:CBuildMakefileDir $entry.Toolchain
                    $tcLinux = (& wsl.exe wslpath -a ($tcWin.Replace('\', '/'))).Trim()
                    $cmakeArgs += "-DCMAKE_TOOLCHAIN_FILE=$tcLinux"
                }

                & wsl.exe --cd "$($PWD.Path)" cmake @cmakeArgs
                if ($LASTEXITCODE -ne 0) { throw "Linux ($arch) configure failed: exit code $LASTEXITCODE." }

                Write-Host ">>> Building Linux ($arch) target through WSL2..."
                & wsl.exe --cd "$($PWD.Path)" cmake --build $buildDir --parallel
                if ($LASTEXITCODE -ne 0) { throw "Linux ($arch) build failed: exit code $LASTEXITCODE." }
            }
        }
        finally {
            Remove-Item -Path (Join-Path $PWD.Path "CMakeLists.txt") -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "`All build jobs completed successfully." -ForegroundColor Green
}