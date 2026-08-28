#Requires -Version 7.4

[CmdletBinding(SupportsShouldProcess)]
param()

$requiredModules = @(
    @{ Name = 'Microsoft.WinGet.Client'; Version = '1.11.460' }
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

$commandNotFoundRoot = Join-Path $PSScriptRoot 'Modules\winget-command-not-found'
$commandNotFoundProject = Join-Path $commandNotFoundRoot 'src\Microsoft.WinGet.CommandNotFound.csproj'
$commandNotFoundInputs = Get-ChildItem `
    -Path (Join-Path $commandNotFoundRoot 'src') `
    -File |
    Where-Object Extension -In '.cs', '.csproj', '.psd1', '.psm1' |
    Sort-Object LastWriteTimeUtc -Descending
$commandNotFoundBuildId = $commandNotFoundInputs[0].LastWriteTimeUtc.Ticks.ToString('x16')
$commandNotFoundOutput = Join-Path $commandNotFoundRoot "src\bin\profile\$commandNotFoundBuildId"
$commandNotFoundManifest = Join-Path $commandNotFoundOutput 'Microsoft.WinGet.CommandNotFound.psd1'

if (-not (Test-Path -LiteralPath $commandNotFoundManifest)) {
    & dotnet build `
        $commandNotFoundProject `
        -c Release `
        -o $commandNotFoundOutput `
        --nologo
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build $commandNotFoundProject."
    }
}

Remove-Variable `
    -Name commandNotFoundRoot, commandNotFoundProject, commandNotFoundInputs, `
        commandNotFoundBuildId, commandNotFoundOutput, commandNotFoundManifest `
    -Force

$localConfigPath = Join-Path $PSScriptRoot '.local\config.psd1'
if (-not (Test-Path -LiteralPath $localConfigPath)) {
    $localConfigDirectory = Split-Path -Parent $localConfigPath
    New-Item -ItemType Directory -Path $localConfigDirectory -Force | Out-Null
    Copy-Item `
        -LiteralPath (Join-Path $PSScriptRoot 'config\local.example.psd1') `
        -Destination $localConfigPath
    Write-Host "Created $localConfigPath. Update it with paths for this machine."
}
