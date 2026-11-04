param(
    [ValidateSet('chrome', 'edge', 'android')]
    [string]$Dispositivo = 'chrome'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter-sdk.ps1')
$stockGoFlutter = Get-StockGoFlutter
Push-Location (Join-Path $PSScriptRoot '..')
try {
    if ($Dispositivo -eq 'android') {
        $stockGoDevices = (& $stockGoFlutter devices --machine | Out-String) | ConvertFrom-Json
        $stockGoAndroid = @($stockGoDevices | Where-Object { $_.targetPlatform -like 'android-*' })
        if ($stockGoAndroid.Count -ne 1) {
            throw 'Conecta exactamente un teléfono o emulador Android, o usa Flutter: Select Device en VS Code.'
        }
        & $stockGoFlutter run -d $stockGoAndroid[0].id
    } else {
        if (!(Test-Path web/sqlite3.wasm) -or !(Test-Path web/sqflite_sw.js)) {
            & (Join-Path $PSScriptRoot 'preparar.ps1')
        }
        & $stockGoFlutter run -d $Dispositivo --web-hostname=localhost --web-port=8080
    }
    if ($LASTEXITCODE -ne 0) { throw 'Flutter no pudo ejecutar StockGo. Revisa el error anterior.' }
} finally { Pop-Location }
