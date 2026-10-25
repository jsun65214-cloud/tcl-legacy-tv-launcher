[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9_.:-]+$')][string]$Serial,
    [string]$Adb = 'adb',
    [string]$OutputDirectory,
    [switch]$IncludeLogs
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Adb.Common.ps1')
$adbPath = Resolve-AdbPath $Adb
Connect-TvAdb -Adb $adbPath -Serial $Serial
if (-not $OutputDirectory) {
    $root = Split-Path -Parent $PSScriptRoot
    $OutputDirectory = Join-Path $root ('.local\diagnostics\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$profile = Get-TvProfile -Adb $adbPath -Serial $Serial
$profile | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'profile.json') -Encoding UTF8
if ($profile.Api -ne '17') { throw 'The CPU sampler is currently tested only on Android API 17.' }
Write-Host 'Sampling CPU first. Keep the TV in the state you want to inspect (about 15 seconds).'
Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments @('shell','top','-n','5','-d','3','-m','20') |
    Set-Content -LiteralPath (Join-Path $OutputDirectory 'cpu-samples.txt') -Encoding UTF8
$queries = @(
    @{Name='memory'; Args=@('shell','cat','/proc/meminfo')},
    @{Name='memory-by-process'; Args=@('shell','dumpsys','meminfo')},
    @{Name='processes'; Args=@('shell','ps')},
    @{Name='services'; Args=@('shell','dumpsys','activity','services')},
    @{Name='activity-state'; Args=@('shell','dumpsys','activity','processes')},
    @{Name='packages'; Args=@('shell','pm','list','packages','-f')},
    @{Name='storage'; Args=@('shell','df')}
)
if ($IncludeLogs) { $queries += @{Name='logcat'; Args=@('shell','logcat','-d','-v','time','-t','1500')} }
foreach ($query in $queries) {
    Invoke-TvAdb -Adb $adbPath -Serial $Serial -Arguments $query.Args |
        Set-Content -LiteralPath (Join-Path $OutputDirectory ($query.Name + '.txt')) -Encoding UTF8
}
Write-Host "Read-only inspection saved to: $OutputDirectory"
