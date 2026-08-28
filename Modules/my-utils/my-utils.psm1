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
