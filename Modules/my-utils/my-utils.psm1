function Get-Jdk
{
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()] [string]$Version = "1.8",
        [ValidateNotNullOrEmpty()] [string]$Vendor = "*"
    )
    return Resolve-Path ~\.jdks\$Vendor-$Version* `
        | Select-Object -ExpandProperty Path `
        | Where-Object { Test-Path $_ -PathType Container } `
        | Select-Object -Last 1
}

function Get-Java
{
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()] [string]$Version = "1.8",
        [ValidateNotNullOrEmpty()] [string]$Vendor = "*"
    )
    return Get-Jdk $Version $Vendor `
        | Join-Path -ChildPath \bin\java.exe
}

function Run-Java
{
    [CmdletBinding()]
    param (
        [string]$Arg,
        [ValidateNotNullOrEmpty()] [string]$Version = "1.8",
        [ValidateNotNullOrEmpty()] [string]$Vendor = "*"
    )
    return -join ((Get-Java $Version $Vendor), " ", $Arg) `
        | Invoke-Expression
}

function Run-Jar
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Path,
        [string]$Arg,
        [ValidateNotNullOrEmpty()] [string]$Version = "1.8",
        [ValidateNotNullOrEmpty()] [string]$Vendor = "*"
    )
    return -join ((Get-Java $Version $Vendor), " -jar ", $Path, " ", $Arg) `
        | Invoke-Expression
}

function Route-Wsl
{
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()] [Int]$Port = "1.8"
    )

	sudo wsl sudo /etc/init.d/sshd
	$wsl_ip = (wsl hostname -I).trim()
	sudo netsh interface portproxy add v4tov4 listenport=$Port listenaddress=0.0.0.0 connectport=$Port connectaddress=$wsl_ip
}

function Setup-305() {
    opam switch cse305_4.14.2
    (& opam env) -split '\r?\n' | ForEach-Object { Invoke-Expression $_ }
}

function Switch-Codex() {
    param (
        [string]$Account
    )

    cp ~/codex-auth/$Account.json ~/.codex/auth.json
}

function Switch-Worktree {
    param (
        [Parameter(Position = 0)]
        [string]$Name
    )

    $commonGitDir = git rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $commonGitDir) {
        throw 'The current directory is not inside a Git worktree.'
    }

    $relativePath = git rev-parse --show-prefix
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to determine the current path relative to the Git worktree root.'
    }

    $mainWorktree = Split-Path -Parent ([string]$commonGitDir).Trim()
    $target = if ([string]::IsNullOrWhiteSpace($Name)) {
        $mainWorktree
    }
    else {
        "$mainWorktree-$Name"
    }

    $target = [System.IO.Path]::GetFullPath($target).TrimEnd('\', '/')
    $worktrees = git worktree list --porcelain |
        Where-Object { $_ -like 'worktree *' } |
        ForEach-Object {
            [System.IO.Path]::GetFullPath($_.Substring(9)).TrimEnd('\', '/')
        }

    if ($target -notin $worktrees) {
        throw "Git worktree not found: $target"
    }

    if (-not [string]::IsNullOrEmpty($relativePath)) {
        $target = Join-Path $target $relativePath
    }
    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        throw "Directory not found in target worktree: $target"
    }

    Set-Location -LiteralPath $target
}

function CWebp-Batch {
   param(
      [Parameter(Position=0)]
      [AllowEmptyString()]
      [string]$Arguments = "",

      [Parameter(Mandatory=$true, Position=1, ValueFromRemainingArguments=$true)]
      [string[]]$Names,

      [string]$OutputDir = "",

      [string]$Suffix = ""
   )

   $parsedArguments = if ([string]::IsNullOrWhiteSpace($Arguments)) {
      @()
   } else {
      $tokens = $null
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseInput($Arguments, [ref]$tokens, [ref]$errors) | Out-Null

      if ($errors.Count -gt 0) {
         throw "Failed to parse cwebp arguments: $Arguments"
      }

      $tokens |
         Where-Object { $_.Kind -ne [System.Management.Automation.Language.TokenKind]::EndOfInput } |
         ForEach-Object {
            if ($_.PSObject.Properties.Name -contains 'Value') {
               [string]$_.Value
            } else {
               $_.Text
            }
         }
   }

   $resolvedOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
      $null
   } else {
      [System.IO.Path]::GetFullPath($OutputDir)
   }

   if ($resolvedOutputDir) {
      New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
   }

   $reservedOutputPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

   $jobs = $Names | ForEach-Object {
      $inputPath = $_
      $stem = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
      $outputStem = "$stem$Suffix"

      $outputBase = if ($resolvedOutputDir) {
         [System.IO.Path]::Combine($resolvedOutputDir, $outputStem)
      } else {
         $dir = [System.IO.Path]::GetDirectoryName($inputPath)
         if ($dir) { [System.IO.Path]::Combine($dir, $outputStem) } else { $outputStem }
      }

      $outputPath = "$outputBase.webp"
      $sequence = 1

      while ((Test-Path -LiteralPath $outputPath) -or $reservedOutputPaths.Contains($outputPath)) {
         $outputPath = "$outputBase-$sequence.webp"
         $sequence += 1
      }

      $null = $reservedOutputPaths.Add($outputPath)

      [pscustomobject]@{
         InputPath = $inputPath
         OutputPath = $outputPath
      }
   }

   $jobs | ForEach-Object -Parallel {
      $job = $_
      $parsedArguments = $using:parsedArguments

      $commandArguments = @()
      $commandArguments += $parsedArguments
      $commandArguments += $job.InputPath
      $commandArguments += '-o'
      $commandArguments += $job.OutputPath

      & cwebp @commandArguments
   } -ThrottleLimit 16
}

function CWebp-Batch-Lossless {
   param(
      [Parameter(Mandatory=$true, Position=0, ValueFromRemainingArguments=$true)]
      [string[]]$Names,

      [string]$OutputDir = "",

      [string]$Suffix = ""
   )

   CWebp-Batch "-lossless -z 1" @Names -OutputDir $OutputDir -Suffix $Suffix
}

function Turn-OffMonitor {
  if (-not ('MonitorPower' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class MonitorPower {
  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
}
"@
  }

  [MonitorPower]::SendMessage([IntPtr]0xffff, 0x0112, [IntPtr]0xF170, [IntPtr]2) | Out-Null
}

function cbfile {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Path)

    Add-Type -AssemblyName System.Windows.Forms
    $files = [System.Collections.Specialized.StringCollection]::new()

    foreach ($p in $Path) {
        $files.Add((Resolve-Path $p).Path)
    }

    [System.Windows.Forms.Clipboard]::SetFileDropList($files)
}
