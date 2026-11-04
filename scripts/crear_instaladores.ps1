param([switch]$SinCompilar)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter-sdk.ps1')
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoFlutter = Get-StockGoFlutter
Push-Location $stockGoRoot
try {
    if (!$SinCompilar) {
        & $stockGoFlutter build web --release --no-wasm-dry-run
        if ($LASTEXITCODE -ne 0) { throw 'Falló web.' }
        & $stockGoFlutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw 'Falló Windows.' }
        & (Join-Path $PSScriptRoot 'compilar_apk.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'Falló Android.' }
    }
    $stockGoRelease = Join-Path $stockGoRoot 'build/windows/x64/runner/Release'
    $stockGoVsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $stockGoVs = & $stockGoVsWhere -latest -products '*' -property installationPath
    $stockGoCrt = Get-ChildItem (Join-Path $stockGoVs 'VC/Redist/MSVC') -Directory |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'x64/Microsoft.VC143.CRT' } |
        Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (!$stockGoCrt) { throw 'No se encontró el runtime de Visual C++.' }
    Copy-Item (Join-Path $stockGoCrt '*.dll') -Destination $stockGoRelease
    $stockGoCompiler = Join-Path $stockGoRoot 'build/tools/inno/ISCC.exe'
    if (!(Test-Path -LiteralPath $stockGoCompiler)) {
        $stockGoCompiler = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
    }
    if (!$stockGoCompiler) { throw 'Instala Inno Setup 6 y agrega ISCC.exe a PATH, o usa build/tools/inno.' }
    & $stockGoCompiler "/DProjectRoot=$stockGoRoot" (Join-Path $stockGoRoot 'installer/windows/stockgo.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Falló el instalador.' }
    Copy-Item 'android_kotlin/app/build/outputs/apk/release/app-release.apk' 'dist/StockGo-Android-pruebas.apk' -Force
    Get-FileHash 'dist/StockGo-Instalador-Windows.exe','dist/StockGo-Android-pruebas.apk' -Algorithm SHA256 |
        ForEach-Object { "$($_.Hash)  $([IO.Path]::GetFileName($_.Path))" } |
        Set-Content 'dist/SHA256.txt'
} finally { Pop-Location }
