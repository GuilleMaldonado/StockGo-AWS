$ErrorActionPreference = 'Stop'
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$key = [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
Write-Host 'Copia esta clave en Render > stockgo-api-demo > Environment > PROVISIONING_KEY.' -ForegroundColor Cyan
Write-Host 'No la compartas con vendedores ni la subas a Git.' -ForegroundColor Yellow
Write-Output $key
