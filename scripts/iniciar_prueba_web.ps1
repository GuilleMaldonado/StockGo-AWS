param([switch]$NoAbrirNavegador)

$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoPython = Join-Path $stockGoRoot '.venv\Scripts\python.exe'
$stockGoPidFile = Join-Path $stockGoRoot 'build\stockgo-prueba-local.json'
$stockGoLogDir = Join-Path $stockGoRoot 'build\logs'

if (!(Test-Path -LiteralPath $stockGoPython)) { throw 'No existe .venv. Ejecuta primero: python -m venv .venv; .\.venv\Scripts\python.exe -m pip install -r backend\requirements-test.txt' }
if (Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue) { throw 'El puerto 8081 ya está ocupado. Ejecuta scripts\detener_prueba_web.ps1 o revisa el proceso existente.' }
if (Get-NetTCPConnection -LocalPort 8082 -State Listen -ErrorAction SilentlyContinue) { throw 'El puerto 8082 ya está ocupado. Ejecuta scripts\detener_prueba_web.ps1 o revisa el proceso existente.' }

New-Item -ItemType Directory -Force $stockGoLogDir | Out-Null
$env:STOCKGO_API_URL = 'http://127.0.0.1:8081'
try { & $stockGoPython (Join-Path $stockGoRoot 'frontend_web\build.py') } finally { Remove-Item Env:STOCKGO_API_URL -ErrorAction SilentlyContinue }
if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar el cliente web.' }

$previousPythonPath, $previousOrigins, $previousApiUrl = $env:PYTHONPATH, $env:ALLOWED_ORIGINS, $env:API_PUBLIC_URL
$env:PYTHONPATH = Join-Path $stockGoRoot 'backend'
$env:ALLOWED_ORIGINS = 'http://127.0.0.1:8082,http://localhost:8082'
$env:API_PUBLIC_URL = 'http://127.0.0.1:8081'
try {
    $api = Start-Process -FilePath $stockGoPython -ArgumentList '-m', 'stockgo_cloud.start' -WorkingDirectory $stockGoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $stockGoLogDir 'api.out.log') -RedirectStandardError (Join-Path $stockGoLogDir 'api.err.log')
} finally {
    if ($null -eq $previousPythonPath) { Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue } else { $env:PYTHONPATH = $previousPythonPath }
    if ($null -eq $previousOrigins) { Remove-Item Env:ALLOWED_ORIGINS -ErrorAction SilentlyContinue } else { $env:ALLOWED_ORIGINS = $previousOrigins }
    if ($null -eq $previousApiUrl) { Remove-Item Env:API_PUBLIC_URL -ErrorAction SilentlyContinue } else { $env:API_PUBLIC_URL = $previousApiUrl }
}
$web = Start-Process -FilePath $stockGoPython -ArgumentList '-m', 'http.server', '8082', '--directory', 'frontend_web/dist' -WorkingDirectory $stockGoRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $stockGoLogDir 'web.out.log') -RedirectStandardError (Join-Path $stockGoLogDir 'web.err.log')

for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 500
    if (Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue) { break }
}
if (!(Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $api.Id, $web.Id -Force -ErrorAction SilentlyContinue
    throw "La API no inició. Consulta $stockGoLogDir\api.err.log"
}

@{ apiPid = $api.Id; webPid = $web.Id; startedAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $stockGoPidFile -Encoding utf8
Write-Host 'StockGo listo:' -ForegroundColor Green
Write-Host '  Web: http://127.0.0.1:8082'
Write-Host '  API: http://127.0.0.1:8081/health'
Write-Host 'Para detenerlo: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\detener_prueba_web.ps1'
if (!$NoAbrirNavegador) { Start-Process 'http://127.0.0.1:8082' }
