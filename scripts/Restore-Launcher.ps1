[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9_.:-]+$')][string]$Serial,
    [string]$Adb = 'adb'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Adb.Common.ps1')
$adbPath = Resolve-AdbPath $Adb
Connect-TvAdb -Adb $adbPath -Serial $Serial
Assert-TestedTv (Get-TvProfile -Adb $adbPath -Serial $Serial)
$start = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','am','start','-W','-n','com.tcl.cyberui/.MainActivity')
if ($start -notmatch 'Status:\s*ok') { throw "Stock launcher did not start; nothing was uninstalled. $start" }
$result = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('uninstall','local.tv.simplehome')
if ($result -notmatch '(?m)^Success\s*$') { throw "Launcher uninstall failed: $result" }
$packages = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','pm','list','packages')
if ($packages -match '(?m)^package:local\.tv\.simplehome\s*$' -or $packages -notmatch '(?m)^package:com\.tcl\.cyberui\s*$') {
    throw 'The final package state could not be verified.'
}
Write-Host 'Stock launcher opened; only local.tv.simplehome was removed.'
