import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../theme/stockgo_theme.dart';
import '../data/stockgo_store.dart';
import 'windows_servidor_dialog.dart';

/// El navegador no dispone de sockets para alojar un servidor HTTP.
class MaestroWebPanel extends StatelessWidget {
  const MaestroWebPanel({super.key, required this.nombreNegocio, this.store});
  final String nombreNegocio;
  final StockGoStore? store;

  Future<void> _preparar(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Preparar el dispositivo maestro'),
      content: const SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Android', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                'Para probar en tu PC, instala Android Emulator desde SDK Manager y crea un teléfono virtual en Device Manager de Android Studio. Enciéndelo. En VS Code usa Flutter: Select Device, elige el emulador y ejecuta StockGo - dispositivo Android o iOS seleccionado con F5. También puedes conectar un teléfono físico con depuración USB.',
              ),
              SizedBox(height: 20),
              Text('Windows', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                'Instala Visual Studio con Desarrollo para el escritorio con C++, MSVC y Windows SDK. En VS Code selecciona StockGo - Windows (servidor desde la app) y pulsa F5.',
              ),
              SizedBox(height: 20),
              Text('iPhone', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text(
                'Ejecuta la app nativa desde un Mac con Xcode y Flutter, seleccionando el iPhone.',
              ),
              SizedBox(height: 20),
              Text(
                'Dentro de la app instalada',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Crea el negocio e inicia sesión como su administrador. Abre Compartir inventario, pulsa Iniciar servidor y copia el código para tus vendedores.',
              ),
              SizedBox(height: 12),
              Text(
                'Los datos guardados en este navegador no se transfieren automáticamente al teléfono o a Windows. Evita registrar nuevamente el inventario sin comprobar dónde está guardado.',
                style: TextStyle(color: StockGoTheme.muted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [StockGoTheme.navy, Color(0xFF17594F)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: StockGoTheme.teal.withValues(alpha: .16),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.devices_rounded,
              color: Color(0xFF8BE5C1),
              size: 44,
            ),
            const SizedBox(height: 20),
            Text(
              nombreNegocio,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Conecta a tu equipo con un dispositivo maestro',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Estás usando la versión web. Para encender el servidor necesitas StockGo instalado en un teléfono o en Windows.',
              style: TextStyle(color: Color(0xFFD1E9E1), height: 1.5),
            ),
            const SizedBox(height: 24),
            if (store != null &&
                kIsWeb &&
                defaultTargetPlatform == TargetPlatform.windows) ...[
              FilledButton.icon(
                onPressed: () => activarWindowsDesdeNavegador(context, store!),
                icon: const Icon(Icons.desktop_windows_outlined),
                label: const Text('Activar servidor Windows desde aquí'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              key: const ValueKey('preparar_maestro'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: StockGoTheme.navy,
              ),
              onPressed: () => _preparar(context),
              icon: const Icon(Icons.phone_android_rounded),
              label: const Text('Preparar dispositivo maestro'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Un negocio, todo tu equipo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              _Paso(
                numero: '1',
                titulo: 'Administrador en la app instalada',
                descripcion: 'El maestro guarda el inventario y enciende el servidor desde Compartir inventario.',
              ),
              _Paso(
                numero: '2',
                titulo: 'Comparte el código de tu negocio',
                descripcion: 'Copia el código completo desde el maestro. Cada empresa conserva su propio identificador.',
              ),
              _Paso(
                numero: '3',
                titulo: 'Vendedores en la misma Wi-Fi',
                descripcion: 'En Login ingresan el código del negocio, usuario y contraseña y pulsan Conectar e iniciar sesión.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .8),
          border: Border.all(color: StockGoTheme.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.web_rounded, color: StockGoTheme.teal),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este navegador puede consultar un servidor ya encendido. Para conectar, cierra sesión y elige Conectarme a un negocio en Login.',
                style: TextStyle(color: StockGoTheme.muted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.descripcion,
  });
  final String numero, titulo, descripcion;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F2EF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            numero,
            style: const TextStyle(
              color: StockGoTheme.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                descripcion,
                style: const TextStyle(color: StockGoTheme.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
