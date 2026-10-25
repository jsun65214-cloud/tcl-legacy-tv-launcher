function Resolve-AdbPath([string]$Adb) {
    if (Test-Path -LiteralPath $Adb -PathType Leaf) { return (Resolve-Path -LiteralPath $Adb).Path }
    return (Get-Command -Name $Adb -CommandType Application -ErrorAction Stop).Source
}

function Invoke-TvAdb([string]$Adb, [string]$Serial, [string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = & $Adb -s $Serial @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $result = ($lines | ForEach-Object { [string]$_ }) -join "`n"
    if ($code -ne 0 -or $result -match '(?im)^(adb: |error: |Error: )') {
        throw "ADB command failed: $result"
    }
    return $result.Trim()
}

function Connect-TvAdb([string]$Adb, [string]$Serial) {
    if ($Serial -match ':\d+$') {
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $result = & $Adb connect $Serial 2>&1
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        if ($code -ne 0) { throw ($result -join "`n") }
    }
    $state = Invoke-TvAdb -Adb $Adb -Serial $Serial -Arguments @('get-state')
    if ($state -ne 'device') { throw 'The selected device is not connected or authorized.' }
}

function Get-TvProfile([string]$Adb, [string]$Serial) {
    return [pscustomobject]@{
        Device = (Invoke-TvAdb -Adb $Adb -Serial $Serial -Arguments @('shell','getprop','ro.product.device'))
        Board = (Invoke-TvAdb -Adb $Adb -Serial $Serial -Arguments @('shell','getprop','ro.product.board'))
        Android = (Invoke-TvAdb -Adb $Adb -Serial $Serial -Arguments @('shell','getprop','ro.build.version.release'))
        Api = (Invoke-TvAdb -Adb $Adb -Serial $Serial -Arguments @('shell','getprop','ro.build.version.sdk'))
    }
}

function Assert-TestedTv([object]$Profile) {
    if ($Profile.Device -ne 'tcl_901' -or $Profile.Board -ne 'BD_MST036B_D0ABIV_TCL_901' -or $Profile.Api -ne '17') {
        throw 'This installer supports only the documented tcl_901 / MS901 / API 17 profile.'
    }
}
