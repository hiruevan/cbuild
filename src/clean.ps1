function Invoke-cbuildclean() {
    param (
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runWeb,
        [bool]$runLnx,
        [string[]]$lnxArchs = @("x86_64")
    )
    # Get build config
    $cfg = Read-CBuildConfig

    # Helper: remove a directory if it exists.
    $removeFolder = {
        param([string]$Path)

        if (Test-Path -LiteralPath $Path) {
            Write-Host "Deleting $Path"
            Remove-Item -LiteralPath $Path -Recurse -Force `
                -ErrorAction Stop
        }
    }

    # Clean all
    if ($all) {
        Write-Host "`n>>> Cleaning all current builds..."
        & $removeFolder $cfg.BUILD
        & $removeFolder $cfg.BIN
        Write-Host "All directories cleaned successfully." -ForegroundColor Green
        return
    }

    # Clean calculator
    if ($runCal) {
        Write-Host "`n>>> Cleaning calculator build..."
        & $removeFolder "$($cfg.BUILD)/cal"
        & $removeFolder "$($cfg.BIN)/cal"
    }

    # Clean windows
    if ($runWin) {
        Write-Host "`n>>> Cleaning Windows build..."
        & $removeFolder "$($cfg.BUILD)/win"
        & $removeFolder "$($cfg.BIN)/win"
    }

    # Clean webp
    if ($runWeb) {
        Write-Host "`n>>> Cleaning Webpage build..."
        & $removeFolder "$($cfg.BUILD)/webp"
        & $removeFolder "$($cfg.BIN)/webp"
    }

    # Clean linux
    if ($runLnx) {
        foreach ($arch in $lnxArchs) {
            $entry = $script:CBuildLinuxArchs[$arch]
            Write-Host "`n>>> Cleaning Linux ($arch) build..."
            & $removeFolder "$($cfg.BUILD)/$($entry.Dir)"
            & $removeFolder "$($cfg.BIN)/$($entry.Dir)"
        }
        if ($all) {
            & $removeFolder "$($cfg.BUILD)/lnx"
            & $removeFolder "$($cfg.BIN)/lnx"
        }
    }

    Write-Host "Cleaning jobs completed successfully." -ForegroundColor Green
}