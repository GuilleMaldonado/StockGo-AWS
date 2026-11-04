param([switch]$Debug, [switch]$Verificar)
$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoProject = Join-Path $stockGoRoot 'android_kotlin'
if (!$env:JAVA_HOME) { $env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr' }
if (!(Test-Path -LiteralPath (Join-Path $stockGoProject 'local.properties'))) {
    $stockGoSdk = $env:ANDROID_HOME
    if (!$stockGoSdk -and (Test-Path 'C:/Android/sdk')) { $stockGoSdk = 'C:/Android/sdk' }
    if (!$stockGoSdk) { throw 'Configura ANDROID_HOME o android_kotlin/local.properties con la ruta del SDK Android.' }
    [IO.File]::WriteAllText((Join-Path $stockGoProject 'local.properties'), ('sdk.dir=' + $stockGoSdk.Replace('\','/').Replace(':','\:') + [Environment]::NewLine))
}
if (!$Debug) {
    # Carga la firma existente; no imprime ni cambia el secreto protegido.
    & (Join-Path $PSScriptRoot 'compilar_apk.ps1') -SoloPrepararFirma
    $stockGoKeys = Join-Path $env:LOCALAPPDATA 'StockGoBuildKeys'
    $stockGoCredential = Import-Clixml -LiteralPath (Join-Path $stockGoKeys 'firma-secreto.xml')
    $env:STOCKGO_KEYSTORE_PATH = Join-Path $stockGoKeys 'stockgo-release.jks'
    $env:STOCKGO_KEYSTORE_PASSWORD = $stockGoCredential.GetNetworkCredential().Password
}
try {
    Push-Location $stockGoProject
    try {
        $stockGoTasks = @(':app:assembleRelease')
        if ($Debug) { $stockGoTasks = @(':app:assembleDebug') }
        if ($Verificar) {
            . (Join-Path $PSScriptRoot 'python-sdk.ps1')
            $env:STOCKGO_TEST_PYTHON = Get-StockGoPython
            $stockGoTasks += @(':app:testDebugUnitTest', ':app:lintDebug')
        }
        & .\gradlew.bat @stockGoTasks --console=plain
        if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación o verificación de Android Kotlin.' }
        $stockGoVariant = 'release'
        $stockGoName = 'StockGo-Kotlin-Android.apk'
        if ($Debug) { $stockGoVariant = 'debug'; $stockGoName = 'StockGo-Kotlin-Android-debug.apk' }
        $stockGoApk = Join-Path $stockGoProject "app/build/outputs/apk/$stockGoVariant/app-$stockGoVariant.apk"
        $stockGoDist = Join-Path $stockGoRoot 'dist'
        New-Item -ItemType Directory -Force $stockGoDist | Out-Null
        Copy-Item -LiteralPath $stockGoApk -Destination (Join-Path $stockGoDist $stockGoName) -Force
        if (!$Debug) { Copy-Item -LiteralPath $stockGoApk -Destination (Join-Path $stockGoDist 'StockGo-Android-pruebas.apk') -Force }
        Write-Output "APK generado: dist/$stockGoName"
    } finally { Pop-Location }
} finally {
    Remove-Item Env:STOCKGO_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:STOCKGO_KEYSTORE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:STOCKGO_TEST_PYTHON -ErrorAction SilentlyContinue
}
