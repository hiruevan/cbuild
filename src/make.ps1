function Invoke-cbuildmake() {
    param (
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx
    )
    # Get build config
    $cfg = Read-CBuildConfig

    # Build calculator
    if ($runCal) {
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
    if ($runWin) {
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
    if ($runLnx) {
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
    Write-Host "`All build jobs completed successfully." -ForegroundColor Green
}