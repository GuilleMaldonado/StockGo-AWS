# Recuperación por correo

StockGo nunca conserva ni reenvía la contraseña anterior. Cuando se solicita
recuperación, la API manda al correo de soporte el negocio, usuario y código
SG1. Después de que un administrador autenticado restablece la cuenta desde
**Equipo**, se entrega una contraseña temporal nueva que vence en 30 minutos y
obliga al usuario a elegir otra.

## Configuración gratuita con Gmail

En Render abre `stockgo-api-demo` y entra a **Environment**. Agrega estos
valores; marca `SMTP_PASSWORD` como secreto:

| Variable | Valor |
| --- | --- |
| `RECOVERY_EMAIL` | `guillermomaldonado618@gmail.com` |
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USERNAME` | `guillermomaldonado618@gmail.com` |
| `SMTP_PASSWORD` | Contraseña de aplicación de Gmail de 16 caracteres |
| `SMTP_FROM` | `guillermomaldonado618@gmail.com` |

En la cuenta Gmail activa la verificación en dos pasos y crea una **contraseña
de aplicación** para “Mail / StockGo”. No uses ni publiques la contraseña
normal del correo. Guarda los cambios y usa **Manual Deploy**.

Si el correo no está configurado, la solicitud permanece registrada en la
auditoría y el administrador puede entregar la clave temporal manualmente.
