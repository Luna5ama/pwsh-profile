# Render an immediately usable prompt, then import one integration per idle
# callback.  Import-Module -Global makes the event handler's module changes
# available to this interactive session.
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

Import-Module `
    (Join-Path $PSScriptRoot 'Modules\my-utils\my-utils.psm1') `
    -Global `
    -Force `
    -DisableNameChecking `
    -ErrorAction Stop

[System.Collections.Queue]$global:__ProfileAsyncInitQueue = @(
    {
        $vcpkgRoot = $global:PowerShellProfileConfig.VcpkgRoot
        if ($vcpkgRoot) {
            $poshVcpkg = Join-Path $vcpkgRoot 'scripts\posh-vcpkg'
            if (Test-Path -LiteralPath $poshVcpkg) {
                Import-Module $poshVcpkg -Global -ErrorAction Stop
            }
        }
    }
    {
        $poshGitManifest = Join-Path $PSScriptRoot 'Modules\posh-git\src\posh-git.psd1'
        Import-Module `
            $poshGitManifest `
            -Global `
            -Force `
            -ArgumentList $true `
            -ErrorAction Stop
    }
	{
		Import-Module -Name Microsoft.WinGet.CommandNotFound -Global -ErrorAction Stop
	}
)

$profileAsyncInitSubscriber = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -SupportEvent -Action {
    if ($global:__ProfileAsyncInitQueue.Count -gt 0) {
        try {
            & $global:__ProfileAsyncInitQueue.Dequeue()
        }
        catch {
            $Host.UI.WriteErrorLine("Async profile initialization failed: $($_.Exception.Message)")
        }
    }
    else {
        Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId -Force
        Remove-Variable -Name __ProfileAsyncInitQueue -Scope Global -Force
        if ($global:__ProfileAsyncInitSubscriptionId -eq $EventSubscriber.SubscriptionId) {
            Remove-Variable -Name __ProfileAsyncInitSubscriptionId -Scope Global -Force
        }

        if ($global:GitPromptSettings) {
            $GitPromptSettings.EnableFileStatus = $false
            $GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true
            $GitPromptSettings.DefaultPromptPrefix.Text = 'PS $env:username@$(hostname) '
            $GitPromptSettings.DefaultPromptPrefix.ForegroundColor = [ConsoleColor]::Green
        }
    }
}

$global:__ProfileAsyncInitSubscriptionId = $profileAsyncInitSubscriber.SubscriptionId
Remove-Variable -Name profileAsyncInitSubscriber -Force
