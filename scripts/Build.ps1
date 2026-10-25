[CmdletBinding()]
param(
    [string]$Jdk = $env:JAVA_HOME,
    [string]$AndroidJar,
    [string]$BuildTools,
    [string]$KeyStore,
    [string]$KeyAlias = 'simplehome'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root 'app'
$sdk = $env:ANDROID_HOME
if (-not $sdk) { $sdk = $env:ANDROID_SDK_ROOT }
if (-not $AndroidJar -and $sdk) { $AndroidJar = Join-Path $sdk 'platforms\android-17\android.jar' }
if (-not $BuildTools -and $sdk) { $BuildTools = Join-Path $sdk 'build-tools\28.0.3' }
if (-not $Jdk -or -not $AndroidJar -or -not $BuildTools) {
    throw 'Pass -Jdk (JDK 8), -AndroidJar (API 17) and -BuildTools (28.0.3), or configure JAVA_HOME and ANDROID_HOME.'
}
$javac = Join-Path $Jdk 'bin\javac.exe'
$java = Join-Path $Jdk 'bin\java.exe'
$keytool = Join-Path $Jdk 'bin\keytool.exe'
$aapt = Join-Path $BuildTools 'aapt.exe'
$zipalign = Join-Path $BuildTools 'zipalign.exe'
$dx = Join-Path $BuildTools 'lib\dx.jar'
$apksigner = Join-Path $BuildTools 'lib\apksigner.jar'
foreach ($path in @($javac,$java,$keytool,$aapt,$zipalign,$dx,$apksigner,$AndroidJar)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing build tool: $path" }
}
function Invoke-BuildTool([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Build tool failed: $Executable" }
}
$build = Join-Path $root 'build'
$stage = Join-Path $build ('stage-' + [Guid]::NewGuid().ToString('N'))
$classes = Join-Path $stage 'classes'
New-Item -ItemType Directory -Path $classes -Force | Out-Null
$unsigned = Join-Path $stage 'unsigned.apk'
Invoke-BuildTool $aapt @('package','-f','-M',"$app\AndroidManifest.xml",'-S',"$app\res",'-I',$AndroidJar,'-F',$unsigned)
Invoke-BuildTool $javac @('-encoding','UTF-8','-source','7','-target','7','-bootclasspath',$AndroidJar,'-d',$classes,"$app\src\local\tv\simplehome\MainActivity.java")
Invoke-BuildTool $java @('-jar',$dx,'--dex',"--output=$stage\classes.dex",$classes)
Push-Location $stage
try { Invoke-BuildTool $aapt @('add','unsigned.apk','classes.dex') }
finally { Pop-Location }
$aligned = Join-Path $stage 'aligned.apk'
Invoke-BuildTool $zipalign @('-f','4',$unsigned,$aligned)
if ($KeyStore) {
    $KeyStore = (Resolve-Path -LiteralPath $KeyStore).Path
    if (-not $env:TV_KEYSTORE_PASSWORD) { throw 'Set TV_KEYSTORE_PASSWORD for the supplied keystore.' }
    $passwordArgument = 'env:TV_KEYSTORE_PASSWORD'
} else {
    $keyDirectory = Join-Path $root '.local\signing'
    New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
    $KeyStore = Join-Path $keyDirectory 'development.jks'
    if (-not (Test-Path -LiteralPath $KeyStore)) {
        Invoke-BuildTool $keytool @('-genkeypair','-keystore',$KeyStore,'-storepass','android','-keypass','android','-alias',$KeyAlias,'-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Legacy TV Home Development','-noprompt')
    }
    $passwordArgument = 'pass:android'
}
$apk = Join-Path $build 'legacy-tv-home-1.0.apk'
Invoke-BuildTool $java @('-jar',$apksigner,'sign','--ks',$KeyStore,'--ks-key-alias',$KeyAlias,'--ks-pass',$passwordArgument,'--key-pass',$passwordArgument,'--min-sdk-version','17','--v1-signing-enabled','true','--v2-signing-enabled','false','--out',$apk,$aligned)
Invoke-BuildTool $java @('-jar',$apksigner,'verify','--verbose','--min-sdk-version','17',$apk)
Invoke-BuildTool $aapt @('dump','badging',$apk)
$checksum = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
($checksum + '  legacy-tv-home-1.0.apk') | Set-Content -LiteralPath (Join-Path $build 'SHA256SUMS.txt') -Encoding ASCII
Write-Host "Built: $apk"
Write-Host "SHA256: $checksum"
