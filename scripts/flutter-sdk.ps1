$ErrorActionPreference = 'Stop'
function Get-StockGoFlutter {
    $stockGoOnPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($stockGoOnPath) { return $stockGoOnPath.Source }
    $stockGoSdk = 'C:/src/flutter'
    $stockGoProperties = Join-Path $PSScriptRoot '../android/local.properties'
    if (Test-Path -LiteralPath $stockGoProperties) {
        $stockGoSdkLine = Get-Content -LiteralPath $stockGoProperties | Where-Object { $_ -match '^flutter.sdk=' } | Select-Object -First 1
        if ($stockGoSdkLine) { $stockGoSdk = $stockGoSdkLine.Substring(12).Replace('\\', '\').Replace('\:', ':') }
    }
    $stockGoExecutable = Join-Path $stockGoSdk 'bin/flutter.bat'
    if (!(Test-Path -LiteralPath $stockGoExecutable)) {
        throw 'No se encontró Flutter. Configura el SDK o agrega flutter al PATH.'
    }
    return $stockGoExecutable
}
