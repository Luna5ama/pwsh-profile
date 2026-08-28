$defaultsPath = Join-Path $PSScriptRoot 'config\defaults.psd1'
$localPath = Join-Path $PSScriptRoot '.local\config.psd1'

$global:PowerShellProfileConfig = @{}

foreach ($configPath in @($defaultsPath, $localPath)) {
   if (-not (Test-Path -LiteralPath $configPath)) {
      continue
   }

   $config = Import-PowerShellDataFile -LiteralPath $configPath
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

# Function to reload profile
function Reload-Profile {
   @(
      $Profile.AllUsersAllHosts,
      $Profile.AllUsersCurrentHost,
      $Profile.CurrentUserAllHosts,
      $Profile.CurrentUserCurrentHost
   ) | % {
      if(Test-Path $_){
         Write-Verbose "Running $_"
         . $_
     }
   }
}
