function Invoke-cbuildclean() {
    param (
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx
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
    if ($runAll) {
        Write-Host "`n>>> Cleaning all current builds..."
        & $removeFolder $cfg.BUILD
        & $removeFolder $cfg.BIN
        Write-Host "`All directories cleaned successfully." -ForegroundColor Green
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

    # Clean linux
    if ($action -eq "clean" -and $runLnx) {
        Write-Host "`n>>> Cleaning Linux build..."
        & $removeFolder "$($cfg.BUILD)/lnx"
        & $removeFolder "$($cfg.BIN)/lnx"
    }

    Write-Host "`Cleaning jobs completed successfully." -ForegroundColor Green
}