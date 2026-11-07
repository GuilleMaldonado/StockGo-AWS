<#
Comprueba que el despliegue público responde sin imprimir secretos.
Ejemplo:
.\scripts\verificar_render.ps1 -ApiUrl https://stockgo-api-demo.onrender.com -WebUrl https://stockgo-web-demo.onrender.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$ApiUrl,
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$WebUrl
)

$ErrorActionPreference = 'Stop'
$api = $ApiUrl.TrimEnd('/')
$web = $WebUrl.TrimEnd('/')

function Assert-Endpoint {
    param([string]$Name, [string]$Url, [scriptblock]$Check)
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 90
        $data = $response.Content | ConvertFrom-Json
        & $Check $data
        Write-Host "OK  $Name : $Url" -ForegroundColor Green
    } catch {
        Write-Host "ERROR  $Name : $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

Assert-Endpoint -Name 'API health' -Url "$api/health" -Check {
    param($data)
    if (-not $data.configurado -or $data.database -ne 'postgresql') { throw 'La API no informó configuración PostgreSQL.' }
}
Assert-Endpoint -Name 'API ready' -Url "$api/ready" -Check {
    param($data)
    if (-not $data.ok -or $data.database -ne 'postgresql') { throw 'La API no puede confirmar la base de datos.' }
}

try {
    $site = Invoke-WebRequest -Uri $web -UseBasicParsing -TimeoutSec 90
    if ($site.StatusCode -ne 200 -or $site.Content -notmatch 'StockGo') { throw 'El sitio no devolvió la interfaz StockGo.' }
    $config = Invoke-WebRequest -Uri "$web/config.js" -UseBasicParsing -TimeoutSec 90
    if ($config.Content -notmatch [regex]::Escape($api)) { throw 'config.js no apunta a la URL HTTPS indicada de la API.' }
    Write-Host "OK  Sitio web y config.js : $web" -ForegroundColor Green
} catch {
    Write-Host "ERROR  Sitio web : $($_.Exception.Message)" -ForegroundColor Red
    throw
}

Write-Host 'La infraestructura respondió correctamente. Ahora crea un negocio y prueba el SG1 desde web y Android.' -ForegroundColor Cyan
