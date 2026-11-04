function Read-CBuildConfig {
    param([string]$Path = (Join-Path $PWD.Path "Project.mk"))

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No Project.mk found in $($PWD.Path)."
    }

    $cfg = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $line = $line -replace '\s+#.*$', '' # strip inline comments
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -match '^\s*([A-Za-z_]\w*)\s*=\s*"?(.*?)"?\s*$') {
            $cfg[$matches[1].ToUpperInvariant()] = $matches[2]
        } else {
            throw "Unrecognised line in Project.mk: $line"
        }
    }

    $platforms = @()
    if ($cfg["PLATFORMS"]) {
        $raw = ($cfg["PLATFORMS"] -replace '#.*$', '') -replace '"', '' # strip inline comments
        $platforms = @(
            $raw -split '[\s,;]+' |
                Where-Object { $_ } |
                ForEach-Object { $_.ToLowerInvariant() } |
                Select-Object -Unique
        )
    }
    $cfg["PLATFORMS"] = $platforms

    # NAME is the only required key
    if (-not $cfg["NAME"]) { throw "Project.mk is missing NAME." }

    # Defaults (also applied when a key is present but empty)
    if (-not $cfg["TARGET"])      { $cfg["TARGET"]      = $cfg["NAME"] }
    if (-not $cfg["DESCRIPTION"]) { $cfg["DESCRIPTION"] = $cfg["NAME"] }
    if (-not $cfg["BIN"])         { $cfg["BIN"]         = "bin" }
    if (-not $cfg["BUILD"])       { $cfg["BUILD"]       = "build" }
    if (-not $cfg["EXPORT"])      { $cfg["EXPORT"]      = "export" }
    if (-not $cfg["SRCDIR"])      { $cfg["SRCDIR"]      = "src" }
    if (-not $cfg["INCLUDE"])     { $cfg["INCLUDE"]     = "include" }
    if (-not $cfg["RESOURCES"])   { $cfg["RESOURCES"]   = "resources" }
    if (-not $cfg["SRC"])         { $cfg["SRC"]         = "main.c" }
    if (-not $cfg["ICON"])         { $cfg["SRC"]        = "icon.ico" }
    if ($cfg["PLATFORMS"].Count -eq 0) { $cfg["PLATFORMS"] = @("cal", "win", "lnx")}

    # Validate platforms
    $valid = @("cal", "win", "lnx", "lnx-x86_64", "lnx-aarch64", "lnx-armhf")
    $bad = $platforms | Where-Object { $valid -notcontains $_ }
    if ($bad) { throw "Project.mk has unknown PLATFORMS: $($bad -join ', ')" }

    # Normalize dirs
    # path stays relative to the project instead of becoming absolute
    foreach ($key in "BIN", "BUILD", "EXPORT", "SRCDIR", "INCLUDE", "RESOURCES") {
        $cfg[$key] = $cfg[$key].Trim().Trim('/', '\')
    }

    return $cfg
}

function New-CBuildFile {
    param(
        [string]$Template,
        [string]$Destination,
        [hashtable]$Config,
        [string]$Shim = (Join-Path $HOME "cbuild/desk_shim").Replace('\', '/')
    )

    $text = Get-Content -LiteralPath $Template -Raw

    $text = $text.Replace("CNAME", $Config.NAME).
                  Replace("CDESC", $Config.DESCRIPTION).
                  Replace("CTAR",  $Config.TARGET).
                  Replace("CBINDIR", $Config.BIN).
                  Replace("CBUILDDIR", $Config.BUILD).
                  Replace("CRESOURCEDIR", $Config.RESOURCES).
                  Replace("CSRCDIR", $Config.SRCDIR).
                  Replace("CINCDIR", $Config.INCLUDE).
                  Replace("CSRCFILES", $Config.SRC).
                  Replace("CICON", $Config.ICON).
                  Replace("desk_shim/", "$Shim/")

    $dest = Join-Path $PWD.Path $Destination
    [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding $false))
}