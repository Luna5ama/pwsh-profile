#Requires -Version 7.4

[CmdletBinding(SupportsShouldProcess)]
param()

$requiredModules = @(
    @{ Name = 'Microsoft.WinGet.Client'; Version = '1.9.2411' }
    @{ Name = 'Microsoft.WinGet.CommandNotFound'; Version = '1.0.4.0' }
    @{ Name = 'posh-git'; Version = '1.1.0' }
    @{ Name = 'Pscx'; Version = '3.3.2' }
    @{ Name = 'PSProfiler'; Version = '1.0.5.0' }
    @{ Name = 'VSSetup'; Version = '2.2.16' }
)

foreach ($module in $requiredModules) {
    $spec = @{
        ModuleName = $module.Name
        RequiredVersion = $module.Version
    }

    if (Get-Module -ListAvailable -FullyQualifiedName $spec) {
        Write-Host "$($module.Name) $($module.Version) is already installed."
        continue
    }

    Install-PSResource `
        -Name $module.Name `
        -Version $module.Version `
        -Scope CurrentUser `
        -TrustRepository `
        -AcceptLicense `
        -Confirm:$false
}

$localConfigPath = Join-Path $PSScriptRoot '.local\config.psd1'
if (-not (Test-Path -LiteralPath $localConfigPath)) {
    $localConfigDirectory = Split-Path -Parent $localConfigPath
    New-Item -ItemType Directory -Path $localConfigDirectory -Force | Out-Null
    Copy-Item `
        -LiteralPath (Join-Path $PSScriptRoot 'config\local.example.psd1') `
        -Destination $localConfigPath
    Write-Host "Created $localConfigPath. Update it with paths for this machine."
}
