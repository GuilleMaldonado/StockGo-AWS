from dataclasses import dataclass
import os
from urllib.parse import urlsplit


@dataclass
class Settings:
    database_url: str = ''
    environment: str = 'development'
    public_url: str = 'http://127.0.0.1:8081'
    provisioning_key: str = ''
    origins: tuple[str, ...] = ('http://localhost:8080', 'http://127.0.0.1:8080')
    pool_size: int = 3
    max_overflow: int = 2
    sslrootcert: str = ''
    sslmode: str = 'verify-full'

    @classmethod
    def from_env(cls):
        settings = cls(
            database_url=os.getenv('DATABASE_URL', ''), environment=os.getenv('APP_ENV', 'development'),
            public_url=(os.getenv('PUBLIC_API_URL') or os.getenv('RENDER_EXTERNAL_URL') or 'http://127.0.0.1:8081').rstrip('/'),
            provisioning_key=os.getenv('PROVISIONING_KEY', ''),
            origins=tuple(v.strip() for v in os.getenv('ALLOWED_ORIGINS', 'http://localhost:8080,http://127.0.0.1:8080').split(',') if v.strip()),
            pool_size=int(os.getenv('DB_POOL_SIZE', '3')), max_overflow=int(os.getenv('DB_MAX_OVERFLOW', '2')),
            sslrootcert=os.getenv('DB_SSLROOTCERT', ''),
            sslmode=os.getenv('DB_SSLMODE', 'verify-full'),
        )
        if settings.environment == 'production':
            if settings.sslmode not in ('verify-full', 'require'):
                raise ValueError('En producción la conexión PostgreSQL debe usar TLS.')
            if urlsplit(settings.public_url).scheme != 'https' or len(settings.provisioning_key) < 32:
                raise ValueError('Producción requiere PUBLIC_API_URL HTTPS y PROVISIONING_KEY de al menos 32 caracteres.')
            if not settings.sslrootcert:
                import certifi
                settings.sslrootcert = certifi.where()
        return settings
