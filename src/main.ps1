$script:CBuildInstallDir = Join-Path $HOME "cbuild"
$script:CBuildPortShimDir = Join-Path $script:CBuildInstallDir "port_shim"
$script:CBuildCalcShimDir = Join-Path $script:CBuildInstallDir "calc_shim"
$script:CBuildMakefileDir = Join-Path $script:CBuildInstallDir "makefiles"
$script:CBuildHelperDir = Join-Path $HOME "python"

$script:CbiuldVersion = "1.2.14"

function cbuild {
    $cbuildArgs = @($args | ForEach-Object { [string]$_ })

    # Version
    if ($cbuildArgs -contains "--version" -or $cbuildArgs.Count -eq 0) {
        Write-Output "cbuild version " $Script:CbiuldVersion
        return
    }

    # Help
    if ($cbuildArgs -contains "-help" -or
        $cbuildArgs -contains "--help") {

        Write-Host @"
<help.txt>
"@
        return
    }

    # Install flag
    $requirementsDir = Join-Path $script:CBuildInstallDir "requirements.txt"
    $isInstalled = Test-Path -Path $requirementsDir

    $action = $cbuildArgs[0].ToLowerInvariant()
    $flags = @($cbuildArgs | Select-Object -Skip 1)
    $positional = @($flags | Where-Object { $_ -notlike "-*" } | ForEach-Object { $_.ToLowerInvariant() })
    $flags      = @($flags | Where-Object { $_ -like  "-*" })

    # Determine targets
    $forceRun = $flags -contains "-force"
    $runAll = $flags -contains "-all"
    $runCal = $flags -contains "-cal" -or $runAll
    $runWin = $flags -contains "-win" -or $runAll
    $runLnx = $flags -contains "-lnx" -or $runAll

    # Get Linux archs
    $lnxArchs = @("x86_64")
    if ($positional.Count -gt 0) {
        if ($runAll -or -not ($flags -contains "-lnx")) {
            Write-Error "An architecture can only be given with -lnx (not with -all). Run 'cbuild -help'."
            return
        }
        foreach ($p in $positional) {
            if (-not $script:CBuildLinuxArchs.ContainsKey($p)) {
                Write-Error "Unknown Linux architecture '$p'. Valid: $(($script:CBuildLinuxArchs.Keys | Sort-Object) -join ', ')"
                return
            }
        }
        $lnxArchs = @($positional | Select-Object -Unique)
    }

    # === INSTALL command ===
    if ($action -eq "install") {
        Install-cbuild -force $forceRun -runCal $runCal -runWin $runWin -runLnx $runLnx -lnxArchs $lnxArchs
        return
    }

    if (-not $isInstalled) {
        Write-Output "cbuild is not installed. Run 'cbuild install' to install it."
        return
    }

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

    # === UNINSTALL command ===
    if ($action -eq "uninstall") {
        Uninstall-cbuild -Full $runAll -Force $forceRun
    }

    # === CLEAN command ===
    if ($action -eq "clean") {
        Invoke-cbuildclean -all $runAll -runCal $runCal -runWin $runWin -runLnx $runLnx -lnxArchs $lnxArchs
    }

    # === MAKE command ===
    if ($action -eq "make") {
        Invoke-cbuildmake -all $runAll -runCal $runCal -runWin $runWin -runLnx $runLnx -lnxArchs $lnxArchs
    }
}