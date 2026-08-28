# PowerShell profile

Personal PowerShell profiles, scripts, and modules.

## Set up a machine

1. Clone this repository to the PowerShell profile directory reported by
   `$PROFILE.CurrentUserAllHosts`.
2. Run `./bootstrap.ps1` in PowerShell 7.
3. Edit `.local/config.psd1` with paths for the current machine.
4. Start a new PowerShell session.

Third-party modules are deliberately not committed. `bootstrap.ps1` restores
the tested versions, while `Modules/my-utils` remains part of the repository.

Machine-specific paths belong in `.local/config.psd1`, which Git ignores.
