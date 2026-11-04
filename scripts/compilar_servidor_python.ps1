$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'python-sdk.ps1')
$stockGoPython = Get-StockGoPython
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoTools = Join-Path $stockGoRoot 'build/tools/python-packaging'
$stockGoPyInstaller = Join-Path $stockGoTools 'PyInstaller/__init__.py'
if (!(Test-Path -LiteralPath $stockGoPyInstaller)) {
    & $stockGoPython -m pip install --target $stockGoTools -r (Join-Path $stockGoRoot 'servidor_python/requirements-build.txt')
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo preparar el empaquetador del servidor Python.' }
}
& $stockGoPython (Join-Path $stockGoRoot 'servidor_python/empaquetar.py')
if ($LASTEXITCODE -ne 0) { throw 'No se pudo generar el ejecutable del servidor Python.' }
Write-Output 'Ejecutable generado: dist/StockGo-Servidor-Python.exe'
