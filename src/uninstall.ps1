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

function Remove-CBuildProfileLine {
    if (-not (Test-Path -LiteralPath $PROFILE)) { return }

    $lines = @(Get-Content -LiteralPath $PROFILE)
    $kept  = @($lines | Where-Object { $_ -notmatch 'cbuild[\\/]cbuild\.ps1' })

    if ($kept.Count -ne $lines.Count) {
        [System.IO.File]::WriteAllLines($PROFILE, [string[]]$kept,
            (New-Object System.Text.UTF8Encoding $false))
        Write-Host "Removed cbuild from $PROFILE"
    }
}