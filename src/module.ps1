$cbuildSource = $PSCommandPath

New-Module -Name cbuild -ArgumentList $cbuildSource -ScriptBlock {
    param($SourcePath)
    $script:CBuildSource       = $SourcePath
    $script:CBuildVersion      = "1.6.8"
    $script:CBuildInstallDir   = Join-Path $HOME "cbuild"
    $script:CBuildToolchainDir = Join-Path $script:CBuildInstallDir "toolchains"

    <helper_definitions>

    <main.ps1>

    Export-ModuleMember -Function cbuild
} | Import-Module -Force