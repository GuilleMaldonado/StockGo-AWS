# Configuración de red LAN propuesta

El servidor de PC o teléfono escucha en HTTP, puerto 8081, para el prototipo
universitario dentro de la misma red Wi-Fi. El cliente limita HTTP a localhost,
127.0.0.1, IPv4 privadas 10/8, 172.16/12 y 192.168/16, y nombres .local.
No se permite usar HTTP para una dirección pública.

HTTP no cifra las credenciales, tokens, imágenes ni inventario. Otros equipos
con capacidad de observar esa red podrían leer ese tráfico. Esta configuración
no es adecuada para publicar un servicio en Internet. HTTPS requeriría
certificados confiables y configuración adicional para cada servidor móvil.

Cambio Android propuesto, autorizado por el usuario para el prototipo en Wi-Fi:

- Permiso normal android.permission.INTERNET.
- android:usesCleartextTraffic="true" dentro de application.
- La validación de direcciones del cliente restringe HTTP a red privada.

Cambio iOS propuesto, autorizado por el usuario para el prototipo en Wi-Fi:

- NSLocalNetworkUsageDescription para que iOS solicite permiso de red local.
- NSAppTransportSecurity / NSAllowsLocalNetworking = true.
- No se habilita NSAllowsArbitraryLoads.

No se modifican firewall, router, políticas del equipo ni ajustes globales.

