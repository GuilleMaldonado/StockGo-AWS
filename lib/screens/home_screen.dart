import '../widgets/stockgo_showcase.dart';
import '../widgets/stockgo_bottom_navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../widgets/windows_servidor_dialog.dart';
import '../services/windows_control.dart';

import '../data/stockgo_store.dart';
import '../models/producto.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/cerrar_sesion_button.dart';
import 'productos_screen.dart';
import 'registro_screen.dart';
import 'servidor_screen.dart';
import 'equipo_screen.dart';
import 'ventas_screen.dart';
import 'reportes_screen.dart';
import 'cambiar_password_screen.dart';
import '../widgets/negocio_pasos.dart';
import '../widgets/stockgo_design.dart';
import '../widgets/stockgo_module_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Producto> _productos = [];
  bool _cargando = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final productos = await widget.store.buscarProductos(
        incluirInactivos: true,
      );
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _cargando = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudo cargar el resumen.';
        });
      }
    }
  }

  Future<void> _inventario() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductosScreen(store: widget.store),
      ),
    );
    if (mounted && widget.store.usuario != null) await _cargar();
  }

  Future<void> _crearUsuario() async {
    final nombre = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RegistroScreen(store: widget.store)),
    );
    if (mounted && nombre != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Usuario $nombre creado correctamente.')),
      );
    }
  }

  Widget _modulos() => LayoutBuilder(
    builder: (context, constraints) {
      final usuario = widget.store.usuario!;
      final cards = <Widget>[
        StockGoModuleCard(
          title: usuario.puedeAdministrar
              ? 'Gestionar Productos'
              : 'Consultar Productos',
          description: 'Productos, fotos y existencias de tu negocio.',
          icon: Icons.inventory_2_outlined,
          onTap: _inventario,
        ),
        if (usuario.puedeVender)
          StockGoModuleCard(
            title: 'Ventas',
            description: 'Arma una cuenta y vende por unidades o lote.',
            icon: Icons.point_of_sale_rounded,
            color: StockGoTheme.blue,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VentasScreen(store: widget.store),
                ),
              );
              if (mounted && widget.store.usuario != null) await _cargar();
            },
          ),
        if (usuario.puedeVender)
          StockGoModuleCard(
            title: 'Historial y estadísticas',
            description: 'Ventas, productos vendidos y rendimiento.',
            icon: Icons.insights_rounded,
            color: StockGoTheme.blue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReportesScreen(store: widget.store),
              ),
            ),
          ),
        if (usuario.puedeAdministrar) ...[
          StockGoModuleCard(
            title: 'Vendedores y equipo',
            description: 'Consulta tu equipo y comparte invitaciones.',
            icon: Icons.groups_2_outlined,
            color: StockGoTheme.blue,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EquipoScreen(store: widget.store),
              ),
            ),
          ),
          StockGoModuleCard(
            title: 'Compartir inventario',
            description: 'Conecta los dispositivos de tu negocio.',
            icon: Icons.hub_outlined,
            color: StockGoTheme.green,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ServidorScreen(store: widget.store),
              ),
            ),
          ),
          StockGoModuleCard(
            title: 'Crear usuario',
            description: 'Registra una cuenta con nombre y permisos.',
            icon: Icons.person_add_alt_1_outlined,
            onTap: _crearUsuario,
          ),
          if (admitePanelWindows)
            StockGoModuleCard(
              title: 'Abrir en navegador',
              description: 'Abre el panel web de esta computadora.',
              icon: Icons.open_in_browser_rounded,
              color: StockGoTheme.blue,
              onTap: abrirPanelWindows,
            ),
          if (kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            StockGoModuleCard(
              title: 'Activar servidor de esta PC',
              description: 'Comparte el inventario desde Windows.',
              icon: Icons.desktop_windows_outlined,
              color: StockGoTheme.green,
              onTap: () => activarWindowsDesdeNavegador(context, widget.store),
            ),
        ],
      ];
      final columns = constraints.maxWidth >= 1000
          ? 3
          : constraints.maxWidth >= 340
          ? 2
          : 1;
      final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards
            .map((card) => SizedBox(width: width, child: card))
            .toList(),
      );
    },
  );
  Widget _estadistica(
    String titulo,
    String valor,
    IconData icono,
    Color color,
    double width,
  ) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(width < 180 ? 12 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StockGoIconBadge(
              icon: icono,
              color: color,
              size: width < 180 ? 38 : 48,
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: Text(
                _cargando ? '—' : valor,
                key: ValueKey(_cargando ? 'cargando' : valor),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontSize: width < 180 ? 24 : 32),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              titulo,
              style: TextStyle(
                color: StockGoTheme.muted,
                fontSize: width < 180 ? 11 : 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final usuario = widget.store.usuario;
    if (usuario == null) return const SizedBox.shrink();
    final activos = _productos.where((p) => p.activo).toList();
    final unidades = activos.fold<int>(0, (total, p) => total + p.cantidad);
    final agotados = activos.where((p) => p.cantidad == 0).length;
    return Scaffold(
      bottomNavigationBar: StockGoBottomNavigation(
        store: widget.store,
        current: StockGoModule.inicio,
      ),
      appBar: AppBar(
        leading: StockGoModuleMenu(
          store: widget.store,
          current: StockGoModule.inicio,
        ),
        title: Row(
          children: [
            const StockGoIconBadge(icon: Icons.inventory_2_rounded, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'StockGo',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        actions: [
          if (usuario.puedeVender)
            IconButton(
              tooltip: 'Cambiar mi contraseña',
              icon: const Icon(Icons.password_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CambiarPasswordScreen(store: widget.store),
                ),
              ),
            ),
          CerrarSesionButton(store: widget.store),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Hola, ${usuario.nombreCompleto}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F1EC),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          usuario.rol.etiqueta,
                          style: const TextStyle(
                            color: StockGoTheme.teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.store.nombreNegocio,
                    style: TextStyle(color: StockGoTheme.muted),
                  ),
                  const SizedBox(height: 22),
                  StockGoShowcase(
                    title: 'Todo tu negocio, en un solo lugar.',
                    subtitle: 'Consulta productos, controla existencias y trabaja con tu equipo.',
                    onTap: _inventario,
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = 3;
                      final width =
                          (constraints.maxWidth - 16 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _estadistica(
                            'Productos activos',
                            '${activos.length}',
                            Icons.inventory_2_outlined,
                            StockGoTheme.teal,
                            width,
                          ),
                          _estadistica(
                            'Unidades disponibles',
                            '$unidades',
                            Icons.layers_outlined,
                            const Color(0xFF497ED3),
                            width,
                          ),
                          _estadistica(
                            'Productos agotados',
                            '$agotados',
                            Icons.warning_amber_rounded,
                            const Color(0xFFBB7729),
                            width,
                          ),
                        ],
                      );
                    },
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(child: Text(_error!)),
                          TextButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 28),
                  const StockGoSectionHeading(
                    title: 'Tu espacio de trabajo',
                    subtitle: 'Elige lo que necesitas hacer hoy.',
                    icon: Icons.dashboard_customize_outlined,
                  ),
                  const SizedBox(height: 20),
                  _modulos(),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: StockGoTheme.muted,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          usuario.puedeAdministrar
                              ? 'Los productos desactivados se conservan como historial.'
                              : usuario.puedeVender
                              ? 'Puedes consultar el inventario y registrar ventas. Los precios los administra el negocio.'
                              : 'Tu acceso permite consultar productos, sin modificar los datos.',
                          style: const TextStyle(
                            color: StockGoTheme.muted,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (usuario.puedeAdministrar) ...[
                    const SizedBox(height: 24),
                    NegocioPasos(store: widget.store),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
