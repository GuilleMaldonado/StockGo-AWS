$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoPython = Join-Path $stockGoRoot '.venv/Scripts/python.exe'
$env:PYTHONPATH = Join-Path $stockGoRoot 'api'
Push-Location $stockGoRoot
try {
    & $stockGoPython -m pytest api/tests -q
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas PostgreSQL y WebSocket.' }
    & (Join-Path $PSScriptRoot 'compilar_apk.ps1') -Verificar
} finally { Pop-Location }
