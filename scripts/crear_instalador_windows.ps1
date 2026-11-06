$ErrorActionPreference = 'Stop'
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoPython = Join-Path $stockGoRoot '.venv\Scripts\python.exe'
$stockGoDist = Join-Path $stockGoRoot 'dist'
if (!(Test-Path -LiteralPath $stockGoPython)) { throw 'No existe .venv. Crea el entorno virtual antes de generar el ejecutable.' }
& $stockGoPython -m pip install --disable-pip-version-check pyinstaller
if ($LASTEXITCODE -ne 0) { throw 'No se pudo instalar PyInstaller en .venv.' }
Push-Location $stockGoRoot
try {
    & $stockGoPython -m PyInstaller --noconfirm --clean --onefile --windowed --name StockGo-Web --distpath $stockGoDist --workpath build\pyinstaller --specpath build\pyinstaller desktop\iniciar.py
    if ($LASTEXITCODE -ne 0) { throw 'PyInstaller no pudo generar StockGo-Web.exe.' }
} finally { Pop-Location }
Write-Host "Ejecutable generado: $stockGoDist\StockGo-Web.exe" -ForegroundColor Green
