
function Install-CBuildProfile {
    $cbuildScript = Join-Path $HOME "cbuild\cbuild.ps1"

    if (-not (Test-Path -LiteralPath $cbuildScript)) {
        throw "Installed cbuild script not found."
    }

    Unblock-CBuildScript -Path $cbuildScript

    # Determine the persistent execution policy.
    $policies = Get-ExecutionPolicy -List

    # Convert the scope list into a lookup table.
    $policyMap = @{}
    foreach ($entry in $policies) {
        $policyMap[$entry.Scope.ToString()] = $entry.ExecutionPolicy.ToString()
    }

    # Determine the highest-priority persistent policy.
    $policy = if ($policyMap["MachinePolicy"] -ne "Undefined") {
        $policyMap["MachinePolicy"]
    }
    elseif ($policyMap["UserPolicy"] -ne "Undefined") {
        $policyMap["UserPolicy"]
    }
    elseif ($policyMap["CurrentUser"] -ne "Undefined") {
        $policyMap["CurrentUser"]
    }
    else {
        $policyMap["LocalMachine"]
    }

    $allowed = @("RemoteSigned", "Unrestricted", "Bypass")

    if ($policy -notin $allowed) {
        Write-Warning "Cannot safely register cbuild in the profile."
        Write-Warning "Persistent execution policy: $policy"
        return
    }

    $profileDir = Split-Path -Parent $PROFILE

    if (-not (Test-Path -LiteralPath $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force |
            Out-Null
    }

    $profileLine = ". `"$cbuildScript`""

    $existing = if (Test-Path -LiteralPath $PROFILE) {
        Get-Content -LiteralPath $PROFILE -Raw
    }
    else {
        ""
    }

    if ($existing -notmatch 'cbuild[\\/]cbuild\.ps1') {
        Add-Content -LiteralPath $PROFILE `
            -Value $profileLine `
            -Encoding utf8

        Write-Host "Registered cbuild in PowerShell profile." `
            -ForegroundColor Green
    }
    else {
        Write-Host "cbuild profile entry already exists."
    }
}