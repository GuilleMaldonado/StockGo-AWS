param([switch]$SinAtajo)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter-sdk.ps1')
$stockGoFlutter = Get-StockGoFlutter
$stockGoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $stockGoRoot
try {
    & $stockGoFlutter build web --release
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar la interfaz del navegador.' }
    & $stockGoFlutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar Windows. Revisa flutter doctor y las herramientas C++.' }
    $stockGoExe = Join-Path $stockGoRoot 'build/windows/x64/runner/Release/StockGo.exe'
    if (!(Test-Path -LiteralPath $stockGoExe)) { throw 'No se encontro StockGo.exe.' }
    if (!$SinAtajo) {
        $stockGoShell = New-Object -ComObject WScript.Shell
        $stockGoAtajo = $stockGoShell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) 'StockGo proyecto.lnk'))
        $stockGoAtajo.TargetPath = $stockGoExe
        $stockGoAtajo.WorkingDirectory = Split-Path $stockGoExe -Parent
        $stockGoAtajo.Description = 'StockGo: inventario, equipo y servidor del negocio'
        $stockGoAtajo.Save()
    }
    Write-Output "StockGo listo: $stockGoExe"
    Write-Output 'Abre StockGo proyecto desde el escritorio. El panel del navegador esta en http://127.0.0.1:8079/.'
} finally { Pop-Location }
