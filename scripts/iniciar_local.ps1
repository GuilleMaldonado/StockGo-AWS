$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoPython = Join-Path $stockGoRoot '.venv/Scripts/python.exe'
if (!(Test-Path -LiteralPath $stockGoPython)) { throw 'Crea .venv e instala api/requirements.txt antes de iniciar.' }
$env:PYTHONPATH = Join-Path $stockGoRoot 'api'
Push-Location $stockGoRoot
try { & $stockGoPython -m stockgo_cloud.start } finally { Pop-Location }
