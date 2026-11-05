function Complete-CBuild {
    [CmdletBinding()]
    param([switch]$NoInstall)

    function ReplaceVersion {
        param (
            [Parameter(Mandatory = $true)]
            [string]$File,

            [Parameter(Mandatory = $true)]
            [string]$Replacement
        )

        if (!(Test-Path -LiteralPath $File -PathType Leaf)) {
            throw "File not found: $File"
        }

        $Content = [System.IO.File]::ReadAllText($File)

        $Pattern = '\b\d+\.\d+\.\d+\b'
        $UpdatedContent = [regex]::Replace($Content, $Pattern, $Replacement)

        if ($Content -eq $UpdatedContent) {
            Write-Warning "No version numbers found in $File"
            return
        }

        [System.IO.File]::WriteAllText($File, $UpdatedContent)

        Write-Host "Successfully replaced versions in $File" -ForegroundColor Green
    }


    $base     = (Get-Location).ProviderPath
    $root     = Join-Path $base 'src'
    $outFull  = Join-Path $HOME 'cbuild.ps1'
    $mainPath = Join-Path $root 'module.ps1'

    if (-not (Test-Path -LiteralPath $mainPath -PathType Leaf)) {
        throw "src\module.ps1 not found. Run Complete-CBuild from the folder that contains 'src'."
    }

    $utf8Bom   = New-Object System.Text.UTF8Encoding $true
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false

    # Replaces <relative/path.ext> with that file's contents (relative to $Base).
    function Expand-Placeholders {
        param([string]$Text, [string]$Base)

        $pattern = '<([^<>\r\n|*?"]+?\.[A-Za-z0-9]+)>'
        $sb  = New-Object System.Text.StringBuilder
        $pos = 0

        foreach ($m in [regex]::Matches($Text, $pattern)) {
            [void]$sb.Append($Text.Substring($pos, $m.Index - $pos))
            $pos = $m.Index + $m.Length

            $rel    = $m.Groups[1].Value.Trim()
            $target = $null
            try { $target = Join-Path $Base $rel } catch { }

            if ($target -and (Test-Path -LiteralPath $target -PathType Leaf)) {
                $content = [System.IO.File]::ReadAllText($target).TrimEnd("`r", "`n")
                if ($content -match "(?m)^['""]@") {
                    throw "'$rel' contains a line starting with '@ or `"@, which would end the here-string early."
                }
                [void]$sb.Append($content)
            } else {
                # <stdint.h> and friends are C includes, not placeholders: stay quiet
                if ($rel -match '[\\/]') {
                    Write-Warning "Placeholder $($m.Value) not found at '$target'; leaving it unchanged."
                }
                [void]$sb.Append($m.Value)
            }
        }
        [void]$sb.Append($Text.Substring($pos))
        $sb.ToString()
    }

    # ---- Read module.ps1 and work out the bumped version (not saved yet) ----
    $mainText   = [System.IO.File]::ReadAllText($mainPath)
    $verPattern = '(?i)(\$script:CBuildVersion\s*=\s*")(\d+)\.(\d+)\.(\d+)(")'
    $verMatch   = [regex]::Match($mainText, $verPattern)
    $bumpedMain = $null

    if ($verMatch.Success) {
        $g      = $verMatch.Groups
        $oldVer = "$($g[2].Value).$($g[3].Value).$($g[4].Value)"
        $newVer = "$($g[2].Value).$($g[3].Value).$([int]$g[4].Value + 1)"
        $bumpedMain = $mainText.Substring(0, $verMatch.Index) +
                      $g[1].Value + $newVer + $g[5].Value +
                      $mainText.Substring($verMatch.Index + $verMatch.Length)
        $mainText = $bumpedMain

        # Bump README.md & help.txt too
        ReplaceVersion -File "README.md" -Replacement $newVer
        ReplaceVersion -File "help.txt" -Replacement $newVer
    } else {
        Write-Warning 'Could not find $script:CBuildVersion = "x.y.z" in module.ps1; version not bumped.'
    }

    # ---- Collect helper files (everything under src except module.ps1) ----
    $helperFiles = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse |
        Where-Object { $_.FullName -ne $mainPath } |
        Sort-Object FullName

    $helperParts = foreach ($file in $helperFiles) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        (Expand-Placeholders -Text $text -Base $base).TrimEnd("`r", "`n")
    }
    $helpers = @($helperParts) -join "`r`n`r`n"

    # ---- Expand module.ps1 placeholders, then insert helpers at <helper_definitions> ----
    $mainText = Expand-Placeholders -Text $mainText -Base $base

    # Matches the marker line, tolerating indentation and a trailing comment
    $marker = [regex]::Match($mainText, '(?m)^[ \t]*<helper_definitions>[^\r\n]*')
    if ($marker.Success) {
        $combined = $mainText.Substring(0, $marker.Index) + $helpers +
                    $mainText.Substring($marker.Index + $marker.Length)
    } else {
        Write-Warning "No <helper_definitions> line found in module.ps1; appending helpers at the end."
        $combined = $mainText.TrimEnd("`r", "`n") + "`r`n`r`n" + $helpers
    }
    $combined = $combined.TrimEnd("`r", "`n") + "`r`n"

    # ---- Validate before writing anything ----
    $tokens = $null; $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($combined, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        foreach ($e in $parseErrors | Select-Object -First 10) {
            Write-Host ("  line {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) -ForegroundColor Red
        }
        throw "Combined script has $($parseErrors.Count) parse error(s); nothing was written."
    }

    # ---- Success: persist version bump and write output (BOM so 5.1 reads it as UTF-8) ----
    if ($bumpedMain) {
        [System.IO.File]::WriteAllText($mainPath, $bumpedMain, $utf8NoBom)
        Write-Host "Version bumped: $oldVer -> $newVer" -ForegroundColor Cyan
    }
    [System.IO.File]::WriteAllText($outFull, $combined, $utf8Bom)
    Get-Item -LiteralPath $outFull

    if ($NoInstall) { return }

    $tmp = Join-Path $HOME 'cbuild.ps1'
    [System.IO.File]::WriteAllText($tmp, $combined, $utf8Bom)
    . $tmp
    cbuild install -force
    if (Test-Path -Path $tmp) { # Clean up double check
        Write-Host "Removing temp cbuild installer..."
        Remove-Item -Path $tmp
    }
}