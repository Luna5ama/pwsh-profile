$defaultsPath = Join-Path $PSScriptRoot 'config\defaults.psd1'
$localPath = Join-Path $PSScriptRoot '.local\config.psd1'

$global:PowerShellProfileConfig = @{}

foreach ($configPath in @($defaultsPath, $localPath)) {
   if (-not [IO.File]::Exists($configPath)) {
      continue
   }

   $configScript = [scriptblock]::Create([IO.File]::ReadAllText($configPath))
   $configScript.CheckRestrictedLanguage([string[]]@(), [string[]]@(), $false)
   $config = & $configScript
   if ($config -isnot [hashtable]) {
      throw "Profile config '$configPath' must contain a hashtable."
   }

   foreach ($key in $config.Keys) {
      $global:PowerShellProfileConfig[$key] = $config[$key]
   }
}

function Setup-Conda {
   $condaRoot = $global:PowerShellProfileConfig.CondaRoot
   $conda = if ($condaRoot) {
      Join-Path $condaRoot 'Scripts\conda.exe'
   }
   else {
      Get-Command conda.exe -ErrorAction SilentlyContinue |
         Select-Object -ExpandProperty Source -First 1
   }

   if ($conda -and (Test-Path -LiteralPath $conda)) {
      (& $conda 'shell.powershell' 'hook') |
         Out-String |
         Where-Object { $_ } |
         Invoke-Expression
   }
}

function Reload-Profile {
   [CmdletBinding()]
   param()

   $profilePaths = @(
      $PROFILE.CurrentUserAllHosts
      $PROFILE.CurrentUserCurrentHost
   ) |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      Select-Object -Unique

   foreach ($profilePath in $profilePaths) {
      if (-not (Test-Path -LiteralPath $profilePath)) {
         continue
      }

      Write-Verbose "Reloading $profilePath"
      . $profilePath
   }
}
