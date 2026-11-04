param([switch]$SoloPrepararFirma, [switch]$FlutterLegacy)
$ErrorActionPreference = 'Stop'
if (!$SoloPrepararFirma -and !$FlutterLegacy) {
    & (Join-Path $PSScriptRoot 'compilar_android_kotlin.ps1')
    return
}
. (Join-Path $PSScriptRoot 'flutter-sdk.ps1')
$stockGoRoot = Split-Path $PSScriptRoot -Parent
$stockGoKeys = Join-Path $env:LOCALAPPDATA 'StockGoBuildKeys'
$stockGoKey = Join-Path $stockGoKeys 'stockgo-release.jks'
$stockGoSecret = Join-Path $stockGoKeys 'firma-secreto.xml'
$stockGoJdk = 'C:/Program Files/Android/Android Studio/jbr'
New-Item -ItemType Directory -Force $stockGoKeys | Out-Null
if (!(Test-Path -LiteralPath $stockGoKey)) {
    if (Test-Path -LiteralPath $stockGoSecret) { throw 'Existe un secreto de firma sin su clave. Recupera la clave original antes de continuar.' }
    $stockGoBytes = New-Object byte[] 32
    $stockGoRandom = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $stockGoRandom.GetBytes($stockGoBytes) } finally { $stockGoRandom.Dispose() }
    $stockGoPassword = [Convert]::ToBase64String($stockGoBytes)
    $stockGoSecure = ConvertTo-SecureString $stockGoPassword -AsPlainText -Force
    $stockGoCredential = [Management.Automation.PSCredential]::new('stockgo', $stockGoSecure)
    # Windows DPAPI protects this credential for the current Windows user.
    $stockGoCredential | Export-Clixml -LiteralPath $stockGoSecret
    $env:STOCKGO_KEYSTORE_PASSWORD = $stockGoPassword
    & "$stockGoJdk/bin/keytool.exe" -genkeypair -noprompt -keystore $stockGoKey -storetype JKS -alias stockgo -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=StockGo, OU=Desarrollo, O=StockGo, C=GT' -storepass:env STOCKGO_KEYSTORE_PASSWORD -keypass:env STOCKGO_KEYSTORE_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo crear la firma de StockGo.' }
}
if (!(Test-Path -LiteralPath $stockGoSecret)) { throw 'Falta el secreto protegido de la firma original. No se sustituirá la clave.' }
$stockGoCredential = Import-Clixml -LiteralPath $stockGoSecret
$env:STOCKGO_KEYSTORE_PATH = $stockGoKey
$env:STOCKGO_KEYSTORE_PASSWORD = $stockGoCredential.GetNetworkCredential().Password
try {
    if (!$SoloPrepararFirma) {
        Push-Location $stockGoRoot
        try {
            $stockGoFlutter = Get-StockGoFlutter
            & $stockGoFlutter build apk --release --target-platform android-arm,android-arm64
            if ($LASTEXITCODE -ne 0) { throw 'Falló la compilación Android.' }
            New-Item -ItemType Directory -Force dist | Out-Null
            Copy-Item build/app/outputs/flutter-apk/app-release.apk dist/StockGo-Android-pruebas.apk -Force
            $stockGoVersion = [regex]::Match([IO.File]::ReadAllText((Join-Path $stockGoRoot 'pubspec.yaml')), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)').Groups[1].Value
            Copy-Item build/app/outputs/flutter-apk/app-release.apk "dist/StockGo-$stockGoVersion-Android.apk" -Force
        } finally { Pop-Location }
    }
} finally {
    Remove-Item Env:STOCKGO_KEYSTORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:STOCKGO_KEYSTORE_PATH -ErrorAction SilentlyContinue
    $stockGoPassword = $null
}
