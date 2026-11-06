# StockGo Web

Cliente estático. No contiene base de datos, claves de PostgreSQL ni capacidad de alojar el negocio.

```powershell
$env:STOCKGO_API_URL = 'https://api.tu-dominio.example'
python .\frontend_web\build.py
```

Publica el contenido de `frontend_web/dist/` en cualquier host estático HTTPS. La única variable que llega al navegador es `STOCKGO_API_URL`, que es una dirección pública, no un secreto.
