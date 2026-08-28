# PowerShell profile

Personal PowerShell profiles, scripts, and modules.

## Set up a machine

1. Clone this repository with `--recurse-submodules` to the PowerShell profile
   directory reported by `$PROFILE.CurrentUserAllHosts`.
2. Run `./bootstrap.ps1` in PowerShell 7.
3. Edit `.local/config.psd1` with paths for the current machine.
4. Start a new PowerShell session.

Third-party gallery modules are deliberately not committed. `bootstrap.ps1`
restores the tested versions. `Modules/my-utils` is tracked directly, and
`Modules/posh-git` tracks the personal posh-git fork as a Git submodule.

Update the fork checkout with:

```powershell
git -C Modules/posh-git fetch origin master
git -C Modules/posh-git switch master
git -C Modules/posh-git merge --ff-only origin/master
git add Modules/posh-git
```

Machine-specific paths belong in `.local/config.psd1`, which Git ignores.
