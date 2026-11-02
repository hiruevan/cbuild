function Unblock-CBuildScript {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    try {
        $zone = Get-Item -LiteralPath $Path `
            -Stream Zone.Identifier `
            -ErrorAction SilentlyContinue

        if ($zone) {
            Write-Host "Removing Mark of the Web: $Path"
            Unblock-File -LiteralPath $Path -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Could not unblock $Path`: $($_.Exception.Message)"
    }
}