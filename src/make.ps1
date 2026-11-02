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

    if ($all) {
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

    # Build calculator
    if ($runCal) {
        Write-Host "`n>>> Generating calculator resources..."
        Invoke-CBuildResources -Cfg $cfg -OutDir "$($cfg.BUILD)/cal"

        Write-Host ">>> Preparing Calculator toolchain..."
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
        New-CBuildFile (Join-Path $script:CBuildToolchainDir "toolchain-ti84.mk") "Makefile" $cfg

        Write-Host ">>> Building calculator target..."
        & make

        # Clean up
        Remove-Item -Path (Join-Path $PWD.Path "Makefile") -Force
        $launcher = Join-Path $PWD.Path "$($cfg.BIN)/cal/$($cfg.TARGET)"
        if (Test-Path -LiteralPath $launcher -PathType Leaf) {
            Move-Item -LiteralPath $launcher -Destination "$launcher.8xp" -Force
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Calculator build failed with exit code $LASTEXITCODE."
        }
    }

    # Build windows
    if ($runWin) {
        Write-Host "`n>>> Generating Windows resources..."
        Invoke-CBuildResources -Cfg $cfg -OutDir "$($cfg.BUILD)/win"

        Write-Host ">>> Configuring Windows build..."
        
        New-CBuildFile (Join-Path $script:CBuildToolchainDir "toolchain-desk.cmake") "CMakeLists.txt" $cfg
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
        $winShim   = Join-Path $HOME "cbuild/desk_shim"
        $linuxShim = (& wsl.exe wslpath -a ($winShim.Replace('\', '/'))).Trim()

        # The template is identical for every architecture, so generate it once
        New-CBuildFile (Join-Path $script:CBuildToolchainDir "toolchain-desk.cmake") "CMakeLists.txt" $cfg -Shim $linuxShim

        try {
            foreach ($arch in $lnxArchs) {
                $entry    = $script:CBuildLinuxArchs[$arch]
                $buildDir = "$($cfg.BUILD)/$($entry.Dir)"

                Write-Host "`n>>> Generating Linux ($arch) resources..."
                Invoke-CBuildResources -Cfg $cfg -OutDir $buildDir

                if ($entry.Toolchain) {
                    & wsl.exe dpkg -s $entry.Compiler 2>&1 | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        throw "Cross compiler for '$arch' is not installed. Run 'cbuild install -lnx $arch'."
                    }
                }

                Write-Host ">>> Configuring Linux ($arch) build..."
                $cmakeArgs = @(
                    "-S", ".", "-B", $buildDir, "-G", "Ninja",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DCBUILD_LNX_DIR=$($entry.Dir)"
                )
                if ($entry.Toolchain) {
                    $tcWin   = Join-Path $script:CBuildToolchainDir $entry.Toolchain
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

    Write-Host "All build jobs completed successfully." -ForegroundColor Green
}