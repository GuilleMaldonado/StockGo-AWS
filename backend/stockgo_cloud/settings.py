from dataclasses import dataclass
import os
from urllib.parse import urlsplit


@dataclass
class Settings:
    database_url: str = ''
    environment: str = 'development'
    api_public_url: str = 'http://127.0.0.1:8081'
    provisioning_key: str = ''
    origins: tuple[str, ...] = ('http://localhost:8080', 'http://127.0.0.1:8080')
    pool_size: int = 3
    max_overflow: int = 2
    sslrootcert: str = ''
    sslmode: str = 'verify-full'
    recovery_email: str = ''
    smtp_host: str = ''
    smtp_port: int = 587
    smtp_username: str = ''
    smtp_password: str = ''
    smtp_from: str = ''

    @classmethod
    def from_env(cls):
        settings = cls(
            database_url=os.getenv('DATABASE_URL', ''), environment=os.getenv('APP_ENV', 'development'),
            api_public_url=(os.getenv('API_PUBLIC_URL') or os.getenv('RENDER_EXTERNAL_URL') or 'http://127.0.0.1:8081').rstrip('/'),
            provisioning_key=os.getenv('PROVISIONING_KEY', ''),
            origins=tuple(v.strip() for v in os.getenv('ALLOWED_ORIGINS', 'http://localhost:8080,http://127.0.0.1:8080').split(',') if v.strip()),
            pool_size=int(os.getenv('DB_POOL_SIZE', '3')), max_overflow=int(os.getenv('DB_MAX_OVERFLOW', '2')),
            sslrootcert=os.getenv('DB_SSLROOTCERT', ''),
            sslmode=os.getenv('DB_SSLMODE', 'verify-full'),
            recovery_email=os.getenv('RECOVERY_EMAIL', '').strip(),
            smtp_host=os.getenv('SMTP_HOST', '').strip(), smtp_port=int(os.getenv('SMTP_PORT', '587')),
            smtp_username=os.getenv('SMTP_USERNAME', '').strip(), smtp_password=os.getenv('SMTP_PASSWORD', ''),
            smtp_from=os.getenv('SMTP_FROM', '').strip(),
        )
        if settings.environment == 'production':
            if settings.sslmode not in ('verify-full', 'require'):
                raise ValueError('En producción la conexión PostgreSQL debe usar TLS.')
            if urlsplit(settings.api_public_url).scheme != 'https' or len(settings.provisioning_key) < 32:
                raise ValueError('Producción requiere API_PUBLIC_URL HTTPS y PROVISIONING_KEY de al menos 32 caracteres.')
            if not settings.origins or any(urlsplit(origin).scheme != 'https' for origin in settings.origins):
                raise ValueError('Producción requiere ALLOWED_ORIGINS con los sitios web HTTPS autorizados.')
            if not settings.sslrootcert:
                import certifi
                settings.sslrootcert = certifi.where()
        return settings
