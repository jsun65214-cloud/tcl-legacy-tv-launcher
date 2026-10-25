[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9_.:-]+$')][string]$Serial,
    [Parameter(Mandatory=$true)][string]$Apk,
    [string]$Adb = 'adb'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Adb.Common.ps1')
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$adbPath = Resolve-AdbPath $Adb
Connect-TvAdb -Adb $adbPath -Serial $Serial
$profile = Get-TvProfile -Adb $adbPath -Serial $Serial
Assert-TestedTv $profile
$stock = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','pm','list','packages','-e','com.tcl.cyberui')
if ($stock -notmatch '(?m)^package:com\.tcl\.cyberui\s*$') { throw 'The stock launcher must be installed and enabled.' }
$remoteApk = '/data/local/tmp/legacy-tv-home.apk'
try {
    Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('push',$apkPath,$remoteApk) | Write-Host
    $result = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','pm','install','-r',$remoteApk)
    if ($result -notmatch '(?m)^Success\s*$') { throw "Package install failed: $result" }
    $installed = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','pm','path','local.tv.simplehome')
    if ($installed -notmatch '^package:') { throw 'The launcher package was not found after installation.' }
    $start = Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','am','start','-W','-n','local.tv.simplehome/.MainActivity')
    if ($start -notmatch 'Status:\s*ok') { throw "Could not start launcher: $start" }
    Write-Host 'Installed. Test the remote, HDMI and sound; choose the default HOME on the TV.'
} finally {
    Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','rm','-f',$remoteApk) | Out-Null
}
