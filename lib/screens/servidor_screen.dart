import '../widgets/stockgo_bottom_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/stockgo_store.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/stockgo_design.dart';
import '../widgets/stockgo_module_menu.dart';
import '../widgets/cerrar_sesion_button.dart';
import '../widgets/maestro_web_panel.dart';
import '../network/local_host.dart';

class ServidorScreen extends StatefulWidget {
  const ServidorScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<ServidorScreen> createState() => _ServidorScreenState();
}

class _ServidorScreenState extends State<ServidorScreen> {
  bool _ocupado = false;
  String? _error;
  String? _direccionElegida;

  Future<void> _cambiar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (widget.store.servidorActivo) {
        await widget.store.detenerServidor();
      } else {
        await widget.store.iniciarServidor();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StockGoException
              ? e.mensaje
              : 'No se pudo iniciar el servidor.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _copiar(String texto) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos de conexión copiados.')),
      );
    }
  }

  Widget _paso(String numero, String titulo, String descripcion) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE8F2EF),
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
              const SizedBox(height: 4),
              Text(
                descripcion,
                style: const TextStyle(color: StockGoTheme.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: StockGoBottomNavigation(
      store: widget.store,
      current: StockGoModule.conexion,
    ),
    appBar: AppBar(
      leading: StockGoModuleMenu(
        store: widget.store,
        current: StockGoModule.conexion,
      ),
      title: const Text('Compartir inventario'),
      actions: [CerrarSesionButton(store: widget.store, enabled: !_ocupado)],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              if (widget.store.usuario?.puedeAdministrar != true ||
                  widget.store.conectado) {
                return const Center(
                  child: Text(
                    'Solo el administrador local puede compartir este negocio.',
                  ),
                );
              }
              if (!widget.store.admiteServidorLocal) {
                return MaestroWebPanel(
                  nombreNegocio: widget.store.nombreNegocio,
                  store: widget.store,
                );
              }
              final activo = widget.store.servidorActivo;
              final codigo = widget.store.codigoServidor;
              final direcciones = widget.store.direccionesServidor
                  .where((url) => !url.contains('127.0.0.1'))
                  .toList();
              final direccion = direcciones.contains(_direccionElegida)
                  ? _direccionElegida
                  : direcciones.firstOrNull;
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [StockGoTheme.navy, Color(0xFF17594F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const StockGoIconBadge(
                              icon: Icons.hub_outlined,
                              size: 54,
                              onDark: true,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                activo
                                    ? '● Servidor activo'
                                    : 'Servidor detenido',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.store.nombreNegocio,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tu inventario, conectado con tu equipo.',
                          style: TextStyle(
                            color: Color(0xFFD1E9E1),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _ocupado || !widget.store.admiteServidorLocal
                        ? null
                        : _cambiar,
                    icon: Icon(
                      activo
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
                    label: Text(
                      _ocupado
                          ? 'Preparando…'
                          : activo
                          ? 'Detener servidor'
                          : 'Iniciar servidor',
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (activo && codigo != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.key_outlined,
                                  color: StockGoTheme.teal,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Identificador único del negocio',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F2EF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  codigo,
                                  key: const ValueKey('codigo_servidor'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w800,
                                    color: StockGoTheme.teal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Este identificador pertenece a este negocio y se conserva al reiniciar. Abajo copia el código completo para conectar a tus vendedores.',
                              style: TextStyle(color: StockGoTheme.muted),
                            ),
                            const SizedBox(height: 16),
                            if (direccion != null)
                              DropdownButtonFormField<String>(
                                key: ValueKey('red-$direccion'),
                                initialValue: direccion,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Red para conectar a los vendedores',
                                  helperText: 'En la misma red elige Wi-Fi. Para mantenimiento remoto elige la IP de Tailscale y mantén el túnel conectado en ambos dispositivos.',
                                  helperMaxLines: 3,
                                ),
                                items: [
                                  for (final url in direcciones)
                                    DropdownMenuItem(
                                      value: url,
                                      child: Text(
                                        esHostTunel(Uri.parse(url).host)
                                            ? 'VPN · $url'
                                            : url,
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _direccionElegida = value),
                              ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: direcciones.isEmpty
                                  ? null
                                  : () => _copiar(
                                      widget.store.codigoParaDireccion(
                                        direccion!,
                                      )!,
                                    ),
                              icon: const Icon(Icons.copy_outlined),
                              label: const Text(
                                'Copiar código para el vendedor',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Código de la red seleccionada',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            if (direcciones.isEmpty)
                              const Text(
                                'No se encontró una dirección de red. Conecta el dispositivo a la Wi-Fi y vuelve a iniciar el servidor.',
                              ),
                            for (final url in [?direccion])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText(
                                      url,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      widget.store.codigoParaDireccion(url)!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: StockGoTheme.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => _copiar(
                                        widget.store.codigoParaDireccion(url)!,
                                      ),
                                      icon: const Icon(
                                        Icons.content_copy,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Copiar código de negocio',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cómo conectar otro dispositivo',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 22),
                          _paso(
                            '1',
                            'Activa el servidor',
                            'Solo el administrador del negocio puede compartir su inventario.',
                          ),
                          _paso(
                            '2',
                            'Usa Wi-Fi o una conexión privada',
                            'En la misma red usa el código Wi-Fi. A distancia, instala y autoriza Tailscale en ambos equipos, elige su IP en esta pantalla y comparte ese código. La dirección por sí sola no activa ni verifica el túnel.',
                          ),
                          _paso(
                            '3',
                            'Elige tu acceso',
                            'Inicia sesión con tu cuenta del negocio o entra como invitado. El código no otorga permisos de administrador.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mantén StockGo abierto en el teléfono que aloja el negocio. Cerrar sesión detiene el servidor.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: StockGoTheme.muted),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
