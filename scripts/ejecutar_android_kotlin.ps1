param([string]$Dispositivo)
$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoSdk = $env:ANDROID_HOME
if (!$stockGoSdk) { $stockGoSdk = 'C:/Android/sdk' }
$stockGoAdb = Join-Path $stockGoSdk 'platform-tools/adb.exe'
if (!(Test-Path -LiteralPath $stockGoAdb)) { throw 'Configura ANDROID_HOME e instala Android SDK Platform Tools.' }
$stockGoDevices = @(& $stockGoAdb devices | Select-String '^([^\s]+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
if (!$Dispositivo) {
    if ($stockGoDevices.Count -ne 1) { throw 'Conecta un teléfono autorizado o inicia un emulador. Si hay varios, indica -Dispositivo con su identificador de adb devices.' }
    $Dispositivo = $stockGoDevices[0]
}
if ($stockGoDevices -notcontains $Dispositivo) { throw 'El dispositivo no está disponible o falta autorizar la depuración USB.' }
& (Join-Path $PSScriptRoot 'compilar_android_kotlin.ps1') -Debug
& $stockGoAdb -s $Dispositivo install -r (Join-Path $stockGoRoot 'dist/StockGo-Kotlin-Android-debug.apk')
if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar. No se desinstalará ninguna aplicación ni se borrarán datos.' }
& $stockGoAdb -s $Dispositivo shell am start -n com.stockgo.nativeapp/.MainActivity
if ($LASTEXITCODE -ne 0) { throw 'No se pudo abrir StockGo Kotlin.' }
