param([switch]$Verificar)
$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoKeys = Join-Path $env:LOCALAPPDATA 'StockGoBuildKeys'
$stockGoKey = Join-Path $stockGoKeys 'stockgo-release.jks'
$stockGoSecret = Join-Path $stockGoKeys 'firma-secreto.xml'
if (!(Test-Path -LiteralPath $stockGoKey) -or !(Test-Path -LiteralPath $stockGoSecret)) { throw 'Falta la firma StockGo original. Restaurala antes de generar un APK de distribucion.' }
$stockGoCredential = Import-Clixml -LiteralPath $stockGoSecret
$env:STOCKGO_KEYSTORE_PATH = $stockGoKey
$env:STOCKGO_KEYSTORE_PASSWORD = $stockGoCredential.GetNetworkCredential().Password
$env:JAVA_HOME = 'C:/Program Files/Android/Android Studio/jbr'
$env:STOCKGO_TEST_PYTHON = Join-Path $stockGoRoot '.venv/Scripts/python.exe'
try {
    Push-Location (Join-Path $stockGoRoot 'android_kotlin')
    try {
        if (!(Test-Path local.properties)) { [IO.File]::WriteAllText((Join-Path (Get-Location) 'local.properties'), 'sdk.dir=C\:/Android/sdk') }
        $stockGoTasks = @(':app:assembleRelease')
        if ($Verificar) { $stockGoTasks += @(':app:testDebugUnitTest', ':app:lintDebug') }
        & .\gradlew.bat @stockGoTasks --console=plain
        if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion o las pruebas Kotlin.' }
        New-Item -ItemType Directory -Force (Join-Path $stockGoRoot 'dist') | Out-Null
        Copy-Item -LiteralPath app/build/outputs/apk/release/app-release.apk -Destination (Join-Path $stockGoRoot 'dist/StockGo-Cloud-Android.apk') -Force
    } finally { Pop-Location }
} finally {
    Remove-Item Env:STOCKGO_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:STOCKGO_KEYSTORE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:STOCKGO_TEST_PYTHON -ErrorAction SilentlyContinue
}
