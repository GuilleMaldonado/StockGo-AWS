# APK Android: instalación, firma y compatibilidad

Entrega actual: StockGo 1.2.0, archivo StockGo-1.2.0-Android.apk. Conserva la firma StockGo de las versiones 1.1.1 y 1.1.2. Actualiza también el maestro para usar mantenimiento remoto y recuperación de cuentas. Respalda la información antes de actualizar.

La versión 1.1.1 utiliza un certificado propio de StockGo. La clave privada y el secreto protegido por Windows DPAPI se guardan en %LOCALAPPDATA%\StockGoBuildKeys; no están en el proyecto ni se entregan con la APK. Guarda una copia privada de esta carpeta y conserva el usuario de Windows que puede descifrar el secreto. No regeneres la clave para futuras actualizaciones. En otra PC será necesario recuperar también la contraseña mediante un procedimiento privado; el XML protegido no es portable entre usuarios.

Compilación reproducible: powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\compilar_apk.ps1

Compatibilidad declarada: Android 7.0/API 24 en adelante, teléfonos ARM de 32 bits y ARM64. Se utiliza target API 36 y se verifica la firma del archivo final con apksigner. Esto no significa que se haya probado físicamente cada modelo o versión. La versión de Flutter utilizada (3.47) no admite Android 6 o anteriores: https://docs.flutter.dev/reference/supported-platforms.

La APK anterior tenía una firma Android Debug; la nueva tiene una firma StockGo. Android no permite actualizar una instalación con un certificado diferente. Si ya habías instalado la versión anterior y guardaste datos locales, no la desinstales sin respaldo: pide un procedimiento de migración. En el teléfono de la captura la instalación fue bloqueada y puede que no exista una instalación anterior.

El aviso de la captura indica que Google Play Protect no reconoce al desarrollador. No es un error de versión de Android y una firma válida no acredita que Google haya revisado la aplicación. La nueva firma y el icono propio identifican correctamente a StockGo y permiten actualizaciones consistentes, pero NO garantizan eliminar el aviso de Play Protect.

Abre Más detalles para leer la causa y las opciones concretas que ofrece el teléfono. Si ofrece analizar la app, permite el análisis de Google con conexión a Internet. Si continúa el bloqueo, procede con la revisión/apelación oficial de Play Protect o con un canal de pruebas de Google Play. No desactives globalmente la protección ni interpretes la nueva firma como aprobación de Google. Guía oficial: https://developers.google.com/android/play-protect/warning-dev-guidance.

Comparte el archivo con extensión .apk, no como .zip. Descarga el archivo completo y comprueba el SHA256 si necesitas descartar una copia incompleta. La firma validada en la PC no demuestra que el archivo recibido en WhatsApp sea exactamente el mismo.