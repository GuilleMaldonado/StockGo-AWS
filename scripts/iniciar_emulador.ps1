param([int]$TimeoutSeconds = 360)
$ErrorActionPreference = 'Stop'
$stockGoSdk = 'C:/Android/sdk'
$stockGoEmulator = Join-Path $stockGoSdk 'emulator/emulator.exe'
$stockGoAdb = Join-Path $stockGoSdk 'platform-tools/adb.exe'
$stockGoDevice = 'emulator-5554'
if (!(Test-Path -LiteralPath $stockGoEmulator)) { throw 'Instala Android Emulator en C:/Android/sdk desde SDK Manager.' }
$stockGoAvds = & $stockGoEmulator -list-avds
if ($stockGoAvds -notcontains 'StockGo_Android') { throw 'No existe StockGo_Android. Crea el dispositivo desde Device Manager.' }
$stockGoAcceleration = & $stockGoEmulator -accel-check 2>&1
if ($LASTEXITCODE -ne 0) { throw 'Falta aceleracion del emulador. Si acabas de activar Windows Hypervisor Platform, reinicia Windows antes de pulsar F5. Detalle: ' + ($stockGoAcceleration -join ' ') }
& $stockGoAdb start-server | Out-Null
$stockGoDevices = & $stockGoAdb devices
if ($stockGoDevices -match '^emulator-5554\s') {
  $stockGoName = & $stockGoAdb -s $stockGoDevice emu avd name 2>$null
  if ($stockGoName -notcontains 'StockGo_Android') { throw 'El puerto 5554 pertenece a otro emulador. Cierralo o selecciona ese dispositivo manualmente en Flutter: Select Device.' }
} else {
  # El escritorio inicia el emulador independientemente de la terminal de depuracion.
  # SwiftShader evita depender del cambio entre las GPU Intel y NVIDIA de esta PC.
  $stockGoDesktopShell = New-Object -ComObject Shell.Application
  $stockGoEmulatorArgs = '-avd StockGo_Android -port 5554 -memory 1536 -cores 2 -gpu swiftshader -no-snapshot'
  $stockGoDesktopShell.ShellExecute($stockGoEmulator, $stockGoEmulatorArgs, (Split-Path $stockGoEmulator -Parent), 'open', 1)
}
$stockGoDeadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
  try { $stockGoBoot = & $stockGoAdb -s $stockGoDevice shell getprop sys.boot_completed 2>$null } catch { $stockGoBoot = '' }
  if ($stockGoBoot -match '^1$') {
    $stockGoPackageService = & $stockGoAdb -s $stockGoDevice shell service check package 2>$null
    if ($stockGoPackageService -match 'Service package: found') {
      Write-Output 'StockGo_Android listo para F5.'
      exit 0
    }
  }
  Start-Sleep -Seconds 3
} while ((Get-Date) -lt $stockGoDeadline)
throw 'Android todavia esta arrancando. Espera a ver su pantalla de inicio y vuelve a pulsar F5.'
