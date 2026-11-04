# Migración de datos y anulación de ventas

El servidor nuevo usa PostgreSQL. SQLite solo aparece en el importador para leer una base anterior v10. Las credenciales SQLite con PBKDF2 y salt se conservan; no se descifran ni se recuperan contraseñas en texto.

1. Respalda la base del negocio anterior. No elijas el catálogo general.
2. Configura `.env` con el PostgreSQL de destino y ejecuta sus migraciones Alembic al iniciar.
3. Abre la carpeta nueva StockGo-AWS y ejecuta primero una simulación:

```powershell
$env:PYTHONPATH = "$PWD/api"
.\.venv\Scripts\python.exe -m stockgo_cloud.cli import-sqlite "C:/RUTA/negocio.db" --dry-run
```

4. Revisa el conteo de usuarios, productos y ventas. Sin `--dry-run` se confirma toda la importación en una transacción. Una segunda importación del mismo identificador o nombre se rechaza; no sobrescribe datos.
5. Los identificadores internos pueden cambiar para evitar colisiones entre empresas. Se remapean correctamente las relaciones usuario-venta-producto y se conservan códigos internos, lotes, nombres, hashes e imágenes.
6. El origen se abre en modo de solo lectura y en una fotografía SQLite consistente; no se modifica ni elimina. La simulación hace rollback del destino. El almacenamiento antiguo y PostgreSQL no se sincronizan después: utiliza solo el nuevo maestro para el negocio migrado.

Las ventas anteriores no tenían cliente. Se marcan explícitamente como no registrado en la versión anterior; no se inventan datos personales. Las nuevas requieren nombre y aceptan descripción, sin teléfono, documento, correo ni catálogo de clientes.

## Eliminar una venta

El botón **Eliminar / anular venta** exige Administrador, motivo y confirmación. Cambia el estado a `anulada`, devuelve existencias en la misma transacción y registra quién lo hizo. Volver a enviar la misma anulación no devuelve stock otra vez. El comprobante y su cliente se conservan como historial y se excluyen de ingresos y productividad.

No existe una entidad global Cliente que se elimine separadamente. Si la cuenta de un cliente se cancela, se anula su comprobante. Borrar texto de un nombre o descripción no modifica stock.

Si el producto original se cambió a otro lote después de quedar en cero, la devolución crea un código de retorno separado `...-RET-VENTA-PRODUCTO` con el lote histórico. Así no mezcla existencias de dos fabricantes/lotes. Un producto desactivado no se reactiva automáticamente al recuperar sus unidades.

Las ventas usan importes en centavos para los comprobantes, `NUMERIC` para precios, bloqueo de filas y un identificador idempotente de solicitud. Una venta simultánea no puede vender unidades inexistentes. Si la conexión se corta, reintenta la misma cuenta con el mismo identificador; no crees otra antes de comprobar su estado.

## Respaldos para la presentación

El plan gratuito de Render no incluye respaldos administrados y caduca a los 30 días. Antes de esa fecha utiliza `pg_dump` con la conexión externa PostgreSQL indicada por el proveedor, guarda el archivo fuera del repositorio y verifica su restauración en una base de prueba. No guardes contraseñas en comandos compartidos ni subas archivos de respaldo a GitHub. Actualizar el código o el APK no es una copia de seguridad de PostgreSQL.
