function complete-cbuild() {
    $base    = (Get-Location).ProviderPath
    $root    = Join-Path $base 'src'
    $outFull = Join-Path $base 'cbuild.ps1'

    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "Folder '$root' not found. Run Package-CBuild from the folder that contains 'src'."
    }

    $mainPath = Join-Path $root 'main.ps1'
    if (-not (Test-Path -LiteralPath $mainPath -PathType Leaf)) {
        throw "main.ps1 not found in '$root'."
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding $false

    # ---- Bump the version in main.ps1 (saved back to disk so it persists) ----
    $mainText = Get-Content -LiteralPath $mainPath -Raw
    if ($null -eq $mainText) { $mainText = '' }

    $verPattern = '(\$script:CbiuldVersion\s*=\s*")(\d+)\.(\d+)\.(\d+)(")'
    $verMatch   = [regex]::Match($mainText, $verPattern)

    if ($verMatch.Success) {
        $oldVer = "$($verMatch.Groups[2].Value).$($verMatch.Groups[3].Value).$($verMatch.Groups[4].Value)"
        $newVer = "$($verMatch.Groups[2].Value).$($verMatch.Groups[3].Value).$([int]$verMatch.Groups[4].Value + 1)"

        $verEvaluator = [System.Text.RegularExpressions.MatchEvaluator] {
            param($m)
            $m.Groups[1].Value + $m.Groups[2].Value + '.' + $m.Groups[3].Value + '.' +
                ([int]$m.Groups[4].Value + 1) + $m.Groups[5].Value
        }
        $mainText = [regex]::Replace($mainText, $verPattern, $verEvaluator, 1)
        [System.IO.File]::WriteAllText($mainPath, $mainText, $utf8NoBom)

        Write-Host "Version bumped: $oldVer -> $newVer" -ForegroundColor Cyan
    } else {
        Write-Warning 'Could not find $script:CbiuldVersion = "x.y.z" in main.ps1; version not bumped.'
    }

    # ---- Collect helper files (everything except main.ps1) ----
    $helperFiles = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse |
        Where-Object { $_.FullName -ne $mainPath } |
        Sort-Object FullName

    # Matches <something.ext> - a path with a file extension
    $pattern = '<([^<>\r\n|*?"]+?\.[A-Za-z0-9]+)>'

    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $relPath = $m.Groups[1].Value.Trim()
        $target  = Join-Path $base $relPath

        if (Test-Path -LiteralPath $target -PathType Leaf) {
            return (Get-Content -LiteralPath $target -Raw).TrimEnd("`r", "`n")
        }

        Write-Warning "Placeholder $($m.Value) not found at '$target'; leaving it unchanged."
        return $m.Value
    }

    $helperParts = foreach ($file in $helperFiles) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($null -eq $text) { $text = '' }
        $text = [regex]::Replace($text, $pattern, $evaluator)
        $text.TrimEnd("`r", "`n")
    }
    $helpers = @($helperParts) -join "`r`n`r`n"

    # ---- Insert helpers into main.ps1 at <helper_definitions> ----
    $mainText = [regex]::Replace($mainText, $pattern, $evaluator)

    $markerPattern   = '(?m)^[ \t]*<helper_definitions>[ \t]*\r?$'
    $markerEvaluator = [System.Text.RegularExpressions.MatchEvaluator] { param($m) $helpers }

    if ([regex]::IsMatch($mainText, $markerPattern)) {
        $combined = [regex]::Replace($mainText, $markerPattern, $markerEvaluator, 1)
    } else {
        Write-Warning "No <helper_definitions> line found in main.ps1; appending helpers at the end instead."
        $combined = $mainText.TrimEnd("`r", "`n") + "`r`n`r`n" + $helpers
    }

    $combined = $combined.TrimEnd("`r", "`n") + "`r`n"

    Set-Content -LiteralPath $outFull -Value $combined -Encoding UTF8

    Get-Item -LiteralPath $outFull

    # Reload cbuild
    . ./cbuild.ps1
    # cbuild uninstall -force
    & cbuild install -force
}