Stop-Process -Name lghub -Force
Stop-Process -Name lghub_agent -Force
Stop-Process -Name lghub_system_tray -Force
Stop-Process -Name lghub_updater -Force
net stop MacType
net start MacType
Stop-Process -Name explorer
$profileRoot = Split-Path -Parent $PSScriptRoot
$localConfigPath = Join-Path $profileRoot '.local\config.psd1'
$localConfig = if (Test-Path -LiteralPath $localConfigPath) {
    Import-PowerShellDataFile -LiteralPath $localConfigPath
}
else {
    @{}
}

$lghubPath = if ($localConfig.LghubPath) {
    $localConfig.LghubPath
}
else {
    Join-Path $env:ProgramFiles 'LGHUB\lghub.exe'
}

Start-Process -FilePath $lghubPath -WindowStyle Hidden
exit
