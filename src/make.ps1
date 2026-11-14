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
        [bool]$runWeb,
        [bool]$runLnx,
        [string[]]$lnxArchs = @("x86_64"),

        [bool]$runGC
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

        try {
            Write-Host ">>> Building calculator target..."
            & make

            if ($LASTEXITCODE -ne 0) {
                throw "Calculator build failed with exit code $LASTEXITCODE."
            }
        }
        finally {
            # Clean up
            Remove-Item -Path (Join-Path $PWD.Path "Makefile") -Force -ErrorAction SilentlyContinue
            $launcher = Join-Path $PWD.Path "$($cfg.BIN)/cal/$($cfg.TARGET)"
            if (Test-Path -LiteralPath $launcher -PathType Leaf) {
                Move-Item -LiteralPath $launcher -Destination "$launcher.8xp" -Force
            }
            Write-Host ">>> Completed calculator build."
        }
        
    }

    # Build windows
    if ($runWin) {
        # Check dependencies
        if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
            throw "cmake not found. Run 'cbuild install -win'"
        }

        Write-Host "`n>>> Generating Windows resources..."
        Invoke-CBuildResources -Cfg $cfg -OutDir "$($cfg.BUILD)/win"

        $buildDir = Join-Path (Join-Path $PWD $cfg.BUILD) "win"

        try {
            Write-Host ">>> Configuring Windows build..."

            New-CBuildFile `
                (Join-Path $script:CBuildToolchainDir "toolchain-desk.cmake") `
                "CMakeLists.txt" $cfg

            & cmake -S . -B $buildDir -G Ninja `
                -DCMAKE_BUILD_TYPE=Release

            $exitCode = $LASTEXITCODE

            if ($exitCode -ne 0) {
                throw "Windows configuration failed with exit code $exitCode."
            }

            Write-Host ">>> Building Windows target..."

            & cmake --build $buildDir

            $exitCode = $LASTEXITCODE

            if ($exitCode -ne 0) {
                throw "Windows build failed with exit code $exitCode."
            }
        }
        finally {
            # Clean up
            Remove-Item -Path (Join-Path $PWD.Path "CMakeLists.txt") -Force -ErrorAction SilentlyContinue
            Write-Host ">>> Completed Windows build."
        }
    }

    # Build Webpage
    if ($runWeb) {
        # Check dependencies
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            throw "WSL not found. Run 'cbuild install -webp'"
        }
        & wsl.exe -- bash -lc 'test -x ~/emsdk/upstream/emscripten/emcc'
        if ($LASTEXITCODE -ne 0) { throw "Emscripten not found. Run 'cbuild install -webp'." }

        $winShim   = Join-Path $HOME "cbuild/desk_shim"
        $linuxShim = (& wsl.exe wslpath -a ($winShim.Replace('\', '/'))).Trim()

        $buildDir = "$($cfg.BUILD)/webp"

        # Generate resources
        Write-Host "`n>>> Generating Webpage resources..."
        Invoke-CBuildResources -Cfg $cfg -OutDir $buildDir

        # Generate cmake file
        Write-Host ">>> Configuring Webpage build..."
        New-CBuildFile (Join-Path $script:CBuildToolchainDir "toolchain-desk.cmake") "CMakeLists.txt" $cfg -Shim $linuxShim

        # Generates shell.html
        $text = Get-Content -LiteralPath (Join-Path $script:CBuildInstallDir "web_shim\shell.html") -Raw

        $iconPath = Join-Path $PWD.Path (Join-Path $cfg.RESOURCES $cfg.ICON)
        $link = ''
        if (Test-Path -LiteralPath $iconPath -PathType Leaf) {
            $b64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($iconPath))
            $link = '<link rel="icon" type="image/x-icon" href="data:image/x-icon;base64,' + $b64 + '">'
        }

        $webDir = Join-Path $script:CBuildInstallDir "web_shim"
        $text = Get-Content -LiteralPath (Join-Path $webDir "shell.html") -Raw
        $css  = Get-Content -LiteralPath (Join-Path $webDir "style.css")  -Raw
        $js   = Get-Content -LiteralPath (Join-Path $webDir "module.js")  -Raw

        $text = $text.Replace('__STYLE__', $css).Replace('__MODULE_JS__', $js)
        $text = $text.Replace('__FAVICON_LINK__', $link).Replace('__TITLE__', $cfg.NAME)

        $shellOut = Join-Path (Join-Path $PWD.Path $buildDir) "shell.html"
        [IO.File]::WriteAllText($shellOut, $text, (New-Object Text.UTF8Encoding $false))
        $shellLinux = (& wsl.exe wslpath -a ($shellOut.Replace('\', '/'))).Trim()

        try {
            $env = "source ~/emsdk/emsdk_env.sh >/dev/null 2>&1"

            Write-Host ">>> Building Webpage target..."
            & wsl.exe --cd "$($PWD.Path)" -- bash -lc "$env && emcmake cmake -S . -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Release -DCBUILD_SHELL_FILE=$shellLinux"
            if ($LASTEXITCODE -ne 0) { throw "WebP configure failed: exit code $LASTEXITCODE." }
            
            & wsl.exe --cd "$($PWD.Path)" -- bash -lc "$env && cmake --build $buildDir --parallel"
            if ($LASTEXITCODE -ne 0) { throw "WebP build failed: exit code $LASTEXITCODE." }
        }
        finally {
            # clean up
            Remove-Item -Path (Join-Path $PWD.Path "CMakeLists.txt") -Force -ErrorAction SilentlyContinue
            Write-Host ">>> Completed Webpage build."
        }
    }

    # Build linux
    if ($runLnx) {
        # Check dependencies
        if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
            throw "WSL not found. Run 'cbuild install -lnx'"
        }
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
            Write-Host ">>> Completed Linux build(s)."
        }
    }

    
    
    # Build GameCube
    if ($runGC) {
        Write-Host "`n>>> Begining GameCube build..."
        $image = "devkitpro/devkitppc:20261102"

        $projectRoot = (Get-Location).Path
        $cbuildRoot = Join-Path $HOME "cbuild"
        $gcShimRoot = Join-Path $cbuildRoot "gc_shim"

        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            throw "Docker was not found. Run 'cbuild install -gc'."
        }

        if (-not (Test-Path $cbuildRoot -PathType Container)) {
            throw "cbuild directory not found: $cbuildRoot"
        }

        if (-not (Test-Path $gcShimRoot -PathType Container)) {
            throw "GameCube compatibility layer not found: $gcShimRoot"
        }

        # Verify the Docker toolchain.
        & docker run --rm --entrypoint bash $image -c `
            'export PATH="$DEVKITPPC/bin:$DEVKITPRO/tools/bin:$PATH"; command -v powerpc-eabi-gcc'

        if ($LASTEXITCODE -ne 0) {
            throw "GameCube toolchain not found. Run 'cbuild install -gc'."
        }

        $buildDir = Join-Path $cfg.BUILD "gc"
        $cmakeBuildDir = Join-Path $buildDir "cmake"
        $cmakeBuildDirContainer = "/src/$($cfg.BUILD.Replace('\','/'))/gc/cmake"

        Write-Host ">>> Generating GameCube resources..."
        Invoke-CBuildResources -Cfg $cfg -OutDir $buildDir

        # The cbuild installation is mounted at /cbuild in Docker.
        $dockerShim = "/cbuild/gc_shim"

        Write-Host ">>> Configuring GameCube build..."
        New-CBuildFile `
            (Join-Path $script:CBuildToolchainDir "toolchain-gc.cmake") `
            "CMakeLists.txt" `
            $cfg `
            -Shim $dockerShim

        try {
            Write-Host ">>> Building GameCube target..."

            # Ensure the CMake build directory is clean.
            Remove-Item $cmakeBuildDir -Recurse -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path $cmakeBuildDir -Force | Out-Null

            $containerScript = @"
export PATH="`$DEVKITPPC/bin:`$DEVKITPRO/portlibs/ppc/bin:`$DEVKITPRO/portlibs/gamecube/bin:`$DEVKITPRO/tools/bin:`$PATH"

cmake -S /src -B $cmakeBuildDirContainer -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/opt/devkitpro/cmake/GameCube.cmake &&
cmake --build $cmakeBuildDirContainer --parallel
"@

            # Here-strings use CRLF on Windows; bash chokes on the \r, so normalise to LF.
            $containerScript = $containerScript -replace "`r`n", "`n"

            $dockerArgs = @(
                "run",
                "--rm",
                "--mount", "type=bind,source=$projectRoot,target=/src",
                "--mount", "type=bind,source=$cbuildRoot,target=/cbuild,readonly",
                "--workdir", "/src",
                "--env", "DEVKITPRO=/opt/devkitpro",
                "--env", "DEVKITPPC=/opt/devkitpro/devkitPPC",
                "--env", "PATH=/opt/devkitpro/devkitPPC/bin:/opt/devkitpro/portlibs/ppc/bin:/opt/devkitpro/portlibs/gamecube/bin:/opt/devkitpro/tools/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                $image,
                "bash",
                "-c",
                $containerScript
            )

            & docker @dockerArgs

            if ($LASTEXITCODE -ne 0) {
                throw "GameCube build failed: exit code $LASTEXITCODE."
            }
        }
        finally {
            Remove-Item "CMakeLists.txt" -Force -ErrorAction SilentlyContinue
        }
    }


    Write-Host "All build jobs completed successfully." -ForegroundColor Green
}