function complete-cbuild() {
    $base    = (Get-Location).ProviderPath
    $root    = Join-Path $base 'src'
    $outFull = Join-Path $base  'cbuild.ps1'

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Folder '$root' not found. Run Package-CBuild from the folder that contains 'src'."
    }

    # main.ps1 (in the src root) always goes first; everything else is sorted by path
    $mainPath = Join-Path $root 'main.ps1'
    $files = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse |
        Sort-Object @{ Expression = { $_.FullName -ne $mainPath } }, FullName

    if (-not $files) { throw "No .ps1 files found in '$root'." }

    # Matches <something.ext> - a path with a file extension
    $pattern = '<([^<>\r\n|*?"]+?\.[A-Za-z0-9]+)>'

    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $relPath = $m.Groups[1].Value.Trim()
        $target  = Join-Path $base $relPath

        if (Test-Path -LiteralPath $target -PathType Leaf) {
            # Trim trailing newlines so the inlined text sits cleanly in place
            return (Get-Content -LiteralPath $target -Raw).TrimEnd("`r", "`n")
        }

        Write-Warning "Placeholder $($m.Value) not found at '$target'; leaving it unchanged."
        return $m.Value
    }

    $parts = foreach ($file in $files) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($null -eq $text) { $text = '' }

        $text = [regex]::Replace($text, $pattern, $evaluator)
        $text.TrimEnd("`r", "`n")
    }

    $combined = ($parts -join "`r`n`r`n") + "`r`n"

    Set-Content -LiteralPath $outFull -Value $combined -Encoding UTF8

    Get-Item -LiteralPath $outFull

    # Reload cbuild
    . ./cbuild.ps1
    & cbuild install -force
}