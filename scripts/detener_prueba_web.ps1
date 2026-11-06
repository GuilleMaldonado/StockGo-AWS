$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoPidFile = Join-Path $stockGoRoot 'build\stockgo-prueba-local.json'
if (!(Test-Path -LiteralPath $stockGoPidFile)) { Write-Host 'No hay una prueba StockGo iniciada por este script.'; exit 0 }
$pids = Get-Content -Raw -LiteralPath $stockGoPidFile | ConvertFrom-Json
foreach ($id in @($pids.apiPid, $pids.webPid)) {
    # Uvicorn y http.server pueden crear un hijo; /T limita el cierre a ese árbol.
    if ($id) { & taskkill.exe /PID $id /T /F 2>$null | Out-Null }
}
Remove-Item -LiteralPath $stockGoPidFile -Force
Write-Host 'Servicios locales StockGo detenidos.' -ForegroundColor Yellow
