$script:CBuildPlatforms = [ordered]@{
    cal = @{ Variants = @('ti84');   Install = ${function:Install-CBuildCalculator}
             Make = ${function:Build-CBuildCal}; Dir = { param($v) 'cal' } }
    win = @{ Variants = @('x86_64'); Install = ${function:Install-CBuildWindows}
             Make = ${function:Build-CBuildWin}; Dir = { param($v) 'win' } }
    lnx = @{ Variants = @('x86_64','aarch64','armhf'); Default = @('x86_64')
             Install = ${function:Install-CBuildLinux}
             Make = ${function:Build-CBuildLnx}; Dir = { param($v) "lnx-$v" } }
}

$script:CBuildCommands = @{
    install   = @{ Flags = 'cal','win','lnx','all','force'; Run = 'Install-cbuild';       NeedsInstall = $false }
    uninstall = @{ Flags = 'all','force';                   Run = 'Uninstall-cbuild';     NeedsInstall = $true  }
    make      = @{ Flags = 'cal','win','lnx','all';         Run = 'Invoke-cbuildmake';    NeedsInstall = $true; NeedsProject = $true }
    clean     = @{ Flags = 'cal','win','lnx','all';         Run = 'Invoke-cbuildclean';   NeedsInstall = $true; NeedsProject = $true }
    export    = @{ Flags = 'cal','win','lnx','all';         Run = 'Invoke-cbuildexport';  NeedsInstall = $true; NeedsProject = $true }
}

function ConvertTo-CBuildFlags {
    param([string[]]$Tokens)

    $flags = [ordered]@{}
    $cur = $null

    foreach ($t in $Tokens) {
        if ($t -like '-*') {
            $cur = $t.TrimStart('-').ToLowerInvariant()

            if (-not $cur) {
                throw "Invalid empty flag."
            }

            if ($flags.Contains($cur)) {
                throw "Duplicate flag '-$cur'."
            }

            $flags[$cur] = @()
        }
        elseif ($cur) {
            # Only Linux accepts positional arguments (architectures).
            if ($cur -ne 'lnx') {
                throw "Flag '-$cur' does not accept arguments. Unexpected value '$t'."
            }

            $flags[$cur] += $t.ToLowerInvariant()
        }
        else {
            throw "Unexpected argument '$t'."
        }
    }

    return $flags
}

function cbuild {
    $argv = @($args | ForEach-Object { [string]$_ })
    try {
        if ($argv.Count -eq 0 -or $argv -contains '-help' -or $argv -contains '--help') {
            Write-Host (Get-Content -Raw (Join-Path $script:CBuildInstallDir 'help.txt')); return
        }
        if ($argv -contains '--version' -or $argv -contains '-version') {
            Write-Output "cbuild version $script:CBuildVersion"; return
        }

        $name = $argv[0].ToLowerInvariant()
        $cmd  = $script:CBuildCommands[$name]
        if (-not $cmd) { throw "Unknown command '$name'. Run 'cbuild -help'." }

        $flags = ConvertTo-CBuildFlags ($argv | Select-Object -Skip 1)
        foreach ($f in $flags.Keys) {
            if ($f -notin $cmd.Flags) { throw "Unknown flag '-$f' for '$name'." }
        }

        $installed = Test-Path (Join-Path $script:CBuildInstallDir 'requirements.txt')
        if ($cmd.NeedsInstall -and -not $installed) { throw "cbuild is not installed. Run 'cbuild install'." }

        if (-not (Get-Command $cmd.Run -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Handler '$($cmd.Run)' is not defined."
        }

        # Linux architectures given after -lnx (default x86_64)
        $lnxArchs = @('x86_64')
        $lnxArgs  = if ($flags.Contains('lnx')) { @($flags['lnx'] | Where-Object { $_ }) } else { @() }
        if ($lnxArgs.Count) {
            foreach ($v in $lnxArgs) {
                if (-not $script:CBuildLinuxArchs.ContainsKey($v)) {
                    throw "Unknown Linux architecture '$v'. Valid: $(($script:CBuildLinuxArchs.Keys | Sort-Object) -join ', ')"
                }
            }
            $lnxArchs = @($lnxArgs | Select-Object -Unique)
        }

        $all = $flags.Contains('all')
        if ($all -and $lnxArgs.Count) { throw "-all cannot be combined with Linux architectures." }
        if ($all -and $flags['all'].Count) { throw "-all does not take arguments." }

        $anyPlatform = @('all','cal','win','lnx') | Where-Object { $flags.Contains($_) }
        if ($cmd.NeedsProject -and -not $anyPlatform) { throw "Specify at least one platform flag." }

        if ($name -eq 'uninstall') {
            & $cmd.Run -Full $all -Force $flags.Contains('force')
        }
        else {
            $params = @{
                all      = $all
                runCal   = $flags.Contains('cal')
                runWin   = $flags.Contains('win')
                runLnx   = $flags.Contains('lnx')
                lnxArchs = $lnxArchs
            }
            if ($name -eq 'install') { $params.force = $flags.Contains('force') }
            & $cmd.Run @params
        }
    }
    catch {
        Write-Error $_.Exception.Message
        $global:LASTEXITCODE = 1
    }
}