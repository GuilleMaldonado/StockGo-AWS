param([string]$ApiUrl = 'http://127.0.0.1:8081')
$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoPython = Join-Path $stockGoRoot '.venv/Scripts/python.exe'
if (!(Test-Path -LiteralPath $stockGoPython)) { throw 'Crea .venv antes de compilar el cliente web.' }
$env:STOCKGO_API_URL = $ApiUrl
try { & $stockGoPython (Join-Path $stockGoRoot 'frontend_web/build.py') } finally { Remove-Item Env:STOCKGO_API_URL -ErrorAction SilentlyContinue }
