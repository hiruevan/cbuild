function Read-CBuildConfig {
    param([string]$Path = (Join-Path $PWD.Path "Project.mk"))

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No Project.mk found in $($PWD.Path)."
    }

    $cfg = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(#.*)?$') { continue }
        if ($line -match '^\s*([A-Za-z_]\w*)\s*=\s*"?(.*?)"?\s*$') {
            $cfg[$matches[1].ToUpperInvariant()] = $matches[2]
        } else {
            throw "Unrecognised line in Project.mk: $line"
        }
    }

        # NAME is the only required key
        if (-not $cfg["NAME"]) { throw "Project.mk is missing NAME." }

        # Defaults (also applied when a key is present but empty)
        if (-not $cfg["TARGET"])      { $cfg["TARGET"]      = $cfg["NAME"] }
        if (-not $cfg["DESCRIPTION"]) { $cfg["DESCRIPTION"] = $cfg["NAME"] }
        if (-not $cfg["BIN"])         { $cfg["BIN"]         = "bin" }
        if (-not $cfg["BUILD"])       { $cfg["BUILD"]       = "build" }
        if (-not $cfg["SRCDIR"])      { $cfg["SRCDIR"]      = "src" }
        if (-not $cfg["INCLUDE"])     { $cfg["INCLUDE"]     = "include" }
        if (-not $cfg["RESOURCES"])   { $cfg["RESOURCES"]   = "resources" }
        if (-not $cfg["SRC"])         { $cfg["SRC"]         = "main.c" }


    # Normalize dirs
    # path stays relative to the project instead of becoming absolute
    foreach ($key in "BIN", "BUILD", "SRCDIR", "INCLUDE", "RESOURCES") {
        $cfg[$key] = $cfg[$key].Trim().Trim('/', '\')
    }

    return $cfg
}

function New-CBuildFile {
    param(
        [string]$Template,
        [string]$Destination,
        [hashtable]$Config,
        [string]$Shim = (Join-Path $HOME "cbuild/port_shim").Replace('\', '/')
    )

    $text = Get-Content -LiteralPath $Template -Raw

    $text = $text.Replace("CNAME", $Config.NAME).
                  Replace("CDESC", $Config.DESCRIPTION).
                  Replace("CTAR",  $Config.TARGET).
                  Replace("CBINDIR", $Config.BIN).
                  Replace("CBUILDDIR", $Config.BUILD).
                  Replace("CSRCDIR", $Config.SRCDIR).
                  Replace("CINCDIR", $Config.INCLUDE).
                  Replace("CSRCFILES", $Config.SRC).
                  Replace("port_shim/", "$Shim/")

    $dest = Join-Path $PWD.Path $Destination
    [System.IO.File]::WriteAllText($dest, $text, (New-Object System.Text.UTF8Encoding $false))
}