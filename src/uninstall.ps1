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

            # Cross-compile toolchains: anything in the table with a toolchain file
            $cross = @($script:CBuildLinuxArchs.Values | Where-Object { $_.Toolchain })
            foreach ($entry in $cross) {
                $deb = $entry.DebArch
                Write-Host ">>> Removing $deb cross-compile packages..."
                & wsl.exe -u root -- bash -c "apt-get remove -y $($entry.Compiler); apt-get purge -y '*:$deb'; dpkg --remove-architecture $deb" 2>&1 | Out-Null
            }
            if ($cross.Count -gt 0) {
                & wsl.exe -u root -- bash -c "rm -f /etc/apt/sources.list.d/cbuild-ports.sources; apt-get autoremove -y" 2>&1 | Out-Null
            }
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

function Get-CBuildProfilePaths {
    $docs  = [Environment]::GetFolderPath('MyDocuments')   # follows OneDrive redirection
    $paths = @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts)
    foreach ($dir in "PowerShell", "WindowsPowerShell") {
        foreach ($name in "profile.ps1", "Microsoft.PowerShell_profile.ps1", "Microsoft.VSCode_profile.ps1") {
            $paths += Join-Path $docs "$dir\$name"
        }
    }
    $paths | Where-Object { $_ } | Sort-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ }
}

function Remove-CBuildProfileLine {
    foreach ($path in Get-CBuildProfilePaths) {
        try {
            $lines = @(Get-Content -LiteralPath $path)
            $kept  = @($lines | Where-Object { $_ -notmatch 'cbuild[\\/]cbuild\.ps1' })

            if ($kept.Count -ne $lines.Count) {
                [System.IO.File]::WriteAllLines($path, [string[]]$kept,
                    (New-Object System.Text.UTF8Encoding $true))
                Write-Host "Removed cbuild from $path"
            }
        }
        catch {
            Write-Warning "Could not update $path ($($_.Exception.Message)). Remove the cbuild line manually."
        }
    }
}