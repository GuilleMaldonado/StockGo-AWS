function Get-StockGoPython {
    $stockGoCandidates = @()
    if ($env:STOCKGO_PYTHON) { $stockGoCandidates += $env:STOCKGO_PYTHON }
    $stockGoPythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($stockGoPythonCommand -and $stockGoPythonCommand.Source -notlike '*WindowsApps*') {
        $stockGoCandidates += $stockGoPythonCommand.Source
    }
    $stockGoLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($stockGoLauncher) {
        $stockGoDetected = & $stockGoLauncher.Source -3 -c 'import sys; print(sys.executable)' 2>$null
        if ($LASTEXITCODE -eq 0) { $stockGoCandidates += $stockGoDetected }
    }
    $stockGoCandidates += (Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
    foreach ($stockGoCandidate in $stockGoCandidates) {
        if (Test-Path -LiteralPath $stockGoCandidate) {
            & $stockGoCandidate -c 'import sys, tkinter, sqlite3; assert sys.version_info >= (3,11)' 2>$null
            if ($LASTEXITCODE -eq 0) { return $stockGoCandidate }
        }
    }
    throw 'Instala Python 3.11 o posterior con Tcl/Tk, o indica su ruta en STOCKGO_PYTHON. No se usa el acceso directo de Microsoft Store.'
}
