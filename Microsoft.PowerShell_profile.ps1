# Render an immediately usable prompt before loading integrations.
function global:prompt {
    "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
}

if ($global:__ProfileAsyncInitSubscriptionId) {
    Unregister-Event `
        -SubscriptionId $global:__ProfileAsyncInitSubscriptionId `
        -Force `
        -ErrorAction SilentlyContinue
    Remove-Variable -Name __ProfileAsyncInitSubscriptionId -Scope Global -Force
}

Remove-Variable -Name __ProfileModuleInitQueue -Scope Global -Force -ErrorAction SilentlyContinue

$useAsyncModuleLoading = $global:PowerShellProfileConfig.AsyncModuleLoading -ne $false

function global:__InvokeProfileModuleInitializer {
    param(
        [Parameter(Mandatory)] $Initializer,
        [Parameter(Mandatory)] [string] $Mode
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $status = 'ok'
    try {
        $null = & $Initializer.Action
    }
    catch {
        $status = 'failed'
        $Host.UI.WriteErrorLine(
            "Profile module initialization failed for $($Initializer.Name): $($_.Exception.Message)"
        )
    }
    finally {
        $stopwatch.Stop()
        if ($global:PowerShellProfileConfig.ShowModuleLoadTiming) {
            Write-Host `
                ('[profile {0}] {1}: {2:N1} ms ({3})' -f `
                    $Mode, $Initializer.Name, $stopwatch.Elapsed.TotalMilliseconds, $status) `
                -ForegroundColor DarkGray
        }
    }
}

$profileModuleInitializers = [System.Collections.Generic.List[object]]::new()
$profileModuleInitializers.Add([pscustomobject]@{
    Name = 'my-utils'
    Action = {
        Import-Module `
            (Join-Path $PSScriptRoot 'Modules\my-utils\my-utils.psm1') `
            -Global `
            -Force `
            -DisableNameChecking `
            -ErrorAction Stop
    }
})

$vcpkgRoot = $global:PowerShellProfileConfig.VcpkgRoot
if ($vcpkgRoot) {
    $poshVcpkg = Join-Path $vcpkgRoot 'scripts\posh-vcpkg'
    if (Test-Path -LiteralPath $poshVcpkg) {
        $profileModuleInitializers.Add([pscustomobject]@{
            Name = 'posh-vcpkg'
            Action = {
                Import-Module $poshVcpkg -Global -ErrorAction Stop
            }.GetNewClosure()
        })
    }
}

$profileModuleInitializers.Add([pscustomobject]@{
    Name = 'posh-git'
    Action = {
        $poshGitManifest = Join-Path $PSScriptRoot 'Modules\posh-git\src\posh-git.psd1'
        if (-not (Get-Module -Name posh-git)) {
            Import-Module `
                $poshGitManifest `
                -Global `
                -ArgumentList $true `
                -ErrorAction Stop
        }

        # Configure the prompt before control returns to PowerShell. Otherwise
        # the first posh-git prompt runs with expensive file-status defaults.
        $GitPromptSettings.EnableFileStatus = $false
        $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true
        $GitPromptSettings.DefaultPromptPrefix.Text = 'PS {0}@{1} ' -f `
            [System.Environment]::UserName, `
            [System.Net.Dns]::GetHostName()
        $GitPromptSettings.DefaultPromptPrefix.ForegroundColor = [ConsoleColor]::Green
    }
})

$profileModuleInitializers.Add([pscustomobject]@{
    Name = 'Microsoft.WinGet.CommandNotFound'
    Action = {
        $commandNotFoundBuildRoot = Join-Path `
            $PSScriptRoot 'Modules\winget-command-not-found\src\bin\profile'
        $commandNotFoundBuildPaths = [IO.Directory]::GetDirectories(
            $commandNotFoundBuildRoot
        )
        [Array]::Sort(
            $commandNotFoundBuildPaths,
            [StringComparer]::CurrentCultureIgnoreCase
        )
        $commandNotFoundManifest = Join-Path `
            $commandNotFoundBuildPaths[-1] 'Microsoft.WinGet.CommandNotFound.psd1'
        Import-Module $commandNotFoundManifest -Global -ErrorAction Stop
    }
})

[System.Collections.Queue]$global:__ProfileModuleInitQueue = $profileModuleInitializers
Remove-Variable -Name profileModuleInitializers, vcpkgRoot, poshVcpkg -Force -ErrorAction SilentlyContinue

if ($useAsyncModuleLoading) {
    $profileAsyncInitSubscriber = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
        if ($global:__ProfileModuleInitQueue.Count -gt 0) {
            __InvokeProfileModuleInitializer `
                -Initializer $global:__ProfileModuleInitQueue.Dequeue() `
                -Mode 'async'
        }
        else {
            $subscriptionId = $EventSubscriber.SubscriptionId
            Unregister-Event -SubscriptionId $subscriptionId -Force
            Remove-Variable -Name __ProfileModuleInitQueue -Scope Global -Force
            Remove-Variable -Name __ProfileAsyncInitSubscriptionId -Scope Global -Force
            Remove-Item Function:\__InvokeProfileModuleInitializer -Force
        }
    }

    $global:__ProfileAsyncInitSubscriptionId = $profileAsyncInitSubscriber.SubscriptionId
    Remove-Variable -Name profileAsyncInitSubscriber -Force
}
else {
    while ($global:__ProfileModuleInitQueue.Count -gt 0) {
        __InvokeProfileModuleInitializer `
            -Initializer $global:__ProfileModuleInitQueue.Dequeue() `
            -Mode 'sync'
    }
    Remove-Variable -Name __ProfileModuleInitQueue -Scope Global -Force
    Remove-Item Function:\__InvokeProfileModuleInitializer -Force
}

Remove-Variable -Name useAsyncModuleLoading -Force
