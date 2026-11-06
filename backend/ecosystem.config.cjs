/**
 * Adaptador operativo para PM2. La API sigue siendo Python/FastAPI;
 * PM2 solo vigila el proceso, lo reinicia y centraliza sus registros.
 * Define STOCKGO_PYTHON con la ruta del Python/venv del servidor.
 */
module.exports = {
  apps: [{
    name: 'stockgo-api',
    cwd: __dirname,
    script: 'stockgo_cloud/start.py',
    interpreter: process.env.STOCKGO_PYTHON || 'python3',
    interpreter_args: '',
    autorestart: true,
    max_restarts: 8,
    min_uptime: '10s',
    kill_timeout: 15000,
    time: true,
    env_production: {
      APP_ENV: 'production',
      PYTHONPATH: __dirname,
      WEB_CONCURRENCY: '1'
    }
  }]
};
