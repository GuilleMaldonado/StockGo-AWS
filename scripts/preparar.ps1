$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter-sdk.ps1')
$stockGoFlutter = Get-StockGoFlutter
Push-Location (Join-Path $PSScriptRoot '..')
try {
    & $stockGoFlutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron instalar las dependencias.' }
    $stockGoDart = Join-Path (Split-Path $stockGoFlutter) 'dart.bat'
    & $stockGoDart run sqflite_common_ffi_web:setup
    if ($LASTEXITCODE -ne 0) { throw 'No se pudieron preparar SQLite y el worker web.' }
    Write-Host 'StockGo está preparado. Selecciona StockGo - Chrome y pulsa F5 en VS Code.'
} finally { Pop-Location }
