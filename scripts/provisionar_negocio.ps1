param(
    [string]$ApiUrl = 'http://127.0.0.1:8081'
)

$ErrorActionPreference = 'Stop'
Write-Host 'Aprovisionamiento reservado para el responsable de StockGo.' -ForegroundColor Yellow
$negocio = Read-Host 'Nombre único del negocio'
$nombres = Read-Host 'Nombres del administrador'
$apellidos = Read-Host 'Apellidos del administrador'
$usuario = Read-Host 'Usuario administrador (letras, puntos o guiones)'
$password = Read-Host 'Contraseña inicial' -AsSecureString
$key = Read-Host 'PROVISIONING_KEY del backend' -AsSecureString

function Reveal([Security.SecureString]$secret) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

$plainPassword = Reveal $password
$plainKey = Reveal $key
try {
    $body = @{ negocio = $negocio; nombres = $nombres; apellidos = $apellidos; usuario = $usuario; password = $plainPassword } | ConvertTo-Json
    $result = Invoke-RestMethod -Uri ($ApiUrl.TrimEnd('/') + '/businesses') -Method Post -ContentType 'application/json' -Headers @{ 'X-StockGo-Provisioning-Key' = $plainKey } -Body $body
    Write-Host "Negocio creado: $($result.nombreNegocio)" -ForegroundColor Green
    Write-Host 'Código SG1 (guárdalo y comparte solo con usuarios autorizados):' -ForegroundColor Green
    Write-Output $result.sg1
} finally {
    Remove-Variable plainPassword, plainKey -ErrorAction SilentlyContinue
}
