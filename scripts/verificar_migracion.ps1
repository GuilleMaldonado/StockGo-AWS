$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'python-sdk.ps1')
. (Join-Path $PSScriptRoot 'flutter-sdk.ps1')
$stockGoPython = Get-StockGoPython
$stockGoFlutter = Get-StockGoFlutter
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$env:STOCKGO_TEST_PYTHON = $stockGoPython
try {
    Push-Location (Join-Path $stockGoRoot 'servidor_python')
    try {
        & $stockGoPython -m unittest discover -s tests -v
        if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas de Python.' }
    } finally { Pop-Location }
    Push-Location $stockGoRoot
    try {
        & $stockGoFlutter test test/python_compatibility_test.dart --concurrency=1
        if ($LASTEXITCODE -ne 0) { throw 'Falló la compatibilidad Flutter/Python.' }
        & $stockGoFlutter analyze --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Falló el análisis Flutter.' }
    } finally { Pop-Location }
    & (Join-Path $PSScriptRoot 'compilar_android_kotlin.ps1') -Debug -Verificar
} finally { Remove-Item Env:STOCKGO_TEST_PYTHON -ErrorAction SilentlyContinue }
