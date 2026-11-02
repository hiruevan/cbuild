function Invoke-cbuildexport() {
    param (
        [bool]$all,
        [bool]$runCal,
        [bool]$runWin,
        [bool]$runLnx,
        [string[]]$lnxArchs = @("x86_64")
    )
    # Get build config
    $cfg = Read-CBuildConfig

    $bin     = $cfg.BIN
    $export  = $cfg.EXPORT
    $extensions = @(".8xp", ".8xv", ".exe", ".elf")

    New-Item -ItemType Directory -Path $export -Force | Out-Null

    if ($all) {
        Write-Host "`n>>> Exporting all binaries..."
        $n = Copy-FilteredFiles -Source $bin -Destination $export -Extensions $extensions
        Write-Host "All binaries exported successfully ($n files)." -ForegroundColor Green
        return
    }

    if ($runCal) {
        Write-Host "`n>>> Exporting calculator binaries..."
        $n = Copy-FilteredFiles -Source (Join-Path $bin "cal") `
                                -Destination (Join-Path $export "cal") `
                                -Extensions $extensions
        Write-Host "    $n file(s) exported." -ForegroundColor Green
    }

    if ($runWin) {
        Write-Host "`n>>> Exporting windows binaries..."
        $n = Copy-FilteredFiles -Source (Join-Path $bin "win") `
                                -Destination (Join-Path $export "win") `
                                -Extensions $extensions
        Write-Host "    $n file(s) exported." -ForegroundColor Green
    }

    if ($runLnx) {
        foreach ($arch in $lnxArchs) {
            Write-Host "`n>>> Exporting linux ($arch) binaries..."
            $folder = "lnx-$arch"
            $n = Copy-FilteredFiles -Source (Join-Path $bin $folder) `
                                    -Destination (Join-Path $export $folder) `
                                    -Extensions $extensions
            Write-Host "    $n file(s) exported." -ForegroundColor Green
        }
    }
}

function Copy-FilteredFiles {
    param (
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string[]]$Extensions
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Host "    Skipping, folder not found: $Source" -ForegroundColor Yellow
        return 0
    }

    # Resolve to a full absolute path so it matches $_.FullName
    $root  = (Resolve-Path -LiteralPath $Source).ProviderPath.TrimEnd('\')
    $count = 0

    Get-ChildItem -LiteralPath $root -Recurse -File |
        Where-Object { $Extensions -contains $_.Extension.ToLower() } |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($root.Length).TrimStart('\')
            $targetPath   = Join-Path $Destination $relativePath
            $targetDir    = Split-Path $targetPath -Parent

            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
            $count++
        }

    return $count
}