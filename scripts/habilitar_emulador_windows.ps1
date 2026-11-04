$ErrorActionPreference = 'Stop'
$stockGoResult = Join-Path $PSScriptRoot 'estado_hipervisor.json'
try {
  $stockGoFeature = Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart
  [pscustomobject]@{ ok=$true; restartNeeded=[bool]$stockGoFeature.RestartNeeded; state=[string]$stockGoFeature.State } | ConvertTo-Json | Set-Content -LiteralPath $stockGoResult -Encoding UTF8
} catch {
  [pscustomobject]@{ ok=$false; error=$_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath $stockGoResult -Encoding UTF8
  exit 1
}
