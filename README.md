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
`Modules/posh-git` and `Modules/winget-command-not-found` track personal forks
as Git submodules. The WinGet CommandNotFound fork defers its private WinGet
client runspace initialization so importing the feedback provider does not block
profile startup on that work. `bootstrap.ps1` builds it into a source-stamped
directory so an existing PowerShell process can keep using its loaded DLL while
a newer build is produced for new sessions.

Update the fork checkout with:

```powershell
git -C Modules/posh-git fetch origin master
git -C Modules/posh-git switch master
git -C Modules/posh-git merge --ff-only origin/master
git add Modules/posh-git
```

Update the WinGet CommandNotFound fork the same way, using `main`:

```powershell
git -C Modules/winget-command-not-found fetch origin main
git -C Modules/winget-command-not-found switch main
git -C Modules/winget-command-not-found merge --ff-only origin/main
git add Modules/winget-command-not-found
./bootstrap.ps1
```

Machine-specific paths belong in `.local/config.psd1`, which Git ignores.

## Compare module loading modes

Set `AsyncModuleLoading` in `.local/config.psd1` and start a new session:

```powershell
@{
    AsyncModuleLoading = $false # $true uses one module per OnIdle callback
}
```

Both modes print the elapsed time and result for each module. Use `$false` to
measure synchronous startup and `$true` to measure the normal asynchronous
loading path.
