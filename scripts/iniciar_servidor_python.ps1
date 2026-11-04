$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'python-sdk.ps1')
$stockGoPython = Get-StockGoPython
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoEntry = Join-Path $stockGoRoot 'servidor_python/iniciar.py'
$stockGoPythonw = Join-Path (Split-Path $stockGoPython -Parent) 'pythonw.exe'
if (Test-Path -LiteralPath $stockGoPythonw) { $stockGoPython = $stockGoPythonw }
Start-Process -FilePath $stockGoPython -ArgumentList @('"' + $stockGoEntry + '"') -WorkingDirectory (Join-Path $stockGoRoot 'servidor_python') -WindowStyle Hidden
