import '../widgets/stockgo_bottom_navigation.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../data/stockgo_repository.dart' show StockGoConexionException;
import '../models/producto.dart';
import '../models/venta.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/stockgo_design.dart';
import '../widgets/stockgo_module_menu.dart';
import '../widgets/perfil_personal_dialog.dart';
import '../widgets/cantidad_venta_dialog.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key, required this.store, this.productoInicial});
  final StockGoStore store;
  final Producto? productoInicial;
  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  List<Producto> _productos = [];
  List<Venta> _ventas = [];
  final _carrito = <int, int>{};
  bool _cargando = true, _guardando = false, _pendiente = false;
  String? _error;
  bool _inicialCargado = false;
  String _solicitud = _nuevaSolicitud();
  static String _nuevaSolicitud() =>
      base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');
  String _importe(int centavos) => (centavos / 100).toStringAsFixed(2);
  Producto _producto(int id) => _productos.firstWhere((p) => p.id == id);
  int get _total => _carrito.entries.fold(
    0,
    (total, l) => total + (_producto(l.key).precio * 100).round() * l.value,
  );
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!(widget.store.usuario?.puedeVender ?? false)) return;
    try {
      final productos = await widget.store.buscarProductos();
      final ventas = await widget.store.listarVentas();
      if (!mounted) return;
      setState(() {
        _productos = productos;
        if (!_inicialCargado) {
          _inicialCargado = true;
          final candidatos = productos.where(
            (p) =>
                p.id == widget.productoInicial?.id &&
                p.cantidad > 0 &&
                p.precio > 0,
          );
          if (candidatos.isNotEmpty) _carrito[candidatos.first.id!] = 1;
        }
        _ventas = ventas;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _agregar() async {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final disponibles = _productos
        .where(
          (p) =>
              p.cantidad > 0 &&
              p.precio > 0 &&
              ((p.ficha['vencimiento'] ?? '').isEmpty ||
                  p.ficha['vencimiento']!.compareTo(hoy) >= 0),
        )
        .toList();
    final producto = await showModalBottomSheet<Producto>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Selecciona producto y lote',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: disponibles.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay productos disponibles para vender.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: disponibles.length,
                        itemBuilder: (context, i) {
                          final p = disponibles[i];
                          return ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(p.nombre),
                            subtitle: Text(
                              '${p.codigo} · Lote: ${p.ficha['lote']?.isNotEmpty == true ? p.ficha['lote'] : 'Sin lote registrado'}\n${p.cantidad} disponibles · ${p.ficha['unidadVenta'] ?? ''}',
                            ),
                            trailing: Text(_importe((p.precio * 100).round())),
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || producto == null) return;
    final cantidad = (_carrito[producto.id] ?? 0) + 1;
    if (cantidad > producto.cantidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya agregaste todas las existencias disponibles.'),
        ),
      );
      return;
    }
    setState(() {
      _carrito[producto.id!] = cantidad;
      _solicitud = _nuevaSolicitud();
      _error = null;
    });
  }

  Future<void> _cantidad(int id) async {
    final cantidad = await showDialog<int>(
      context: context,
      builder: (_) =>
          CantidadVentaDialog(producto: _producto(id), cantidad: _carrito[id]!),
    );
    if (mounted && cantidad != null) {
      setState(() {
        _carrito[id] = cantidad;
        _solicitud = _nuevaSolicitud();
      });
    }
  }

  Future<void> _confirmar() async {
    if (_guardando || _carrito.isEmpty) return;
    if (!widget.store.usuario!.perfilCompleto) {
      await showDialog<void>(
        context: context,
        builder: (_) => PerfilPersonalDialog(store: widget.store),
      );
      if (mounted) setState(() {});
      return;
    }
    if (!_pendiente) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar venta'),
          content: Text(
            'Total: ${_importe(_total)}\nSe descontarán las existencias y se conservará el lote de cada producto.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Registrar venta'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }
    setState(() {
      _guardando = true;
      _pendiente = true;
      _error = null;
    });
    try {
      final venta = await widget.store.registrarVenta(
        _carrito.entries
            .map(
              (l) => LineaVenta(
                productoId: l.key,
                cantidad: l.value,
                precioEsperadoCentavos: (_producto(l.key).precio * 100).round(),
              ),
            )
            .toList(),
        _solicitud,
      );
      if (!mounted) return;
      setState(() {
        _carrito.clear();
        _pendiente = false;
        _solicitud = _nuevaSolicitud();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Venta #${venta.id} registrada · Total ${_importe(venta.totalCentavos)}',
          ),
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendiente = e is StockGoConexionException;
        _error = _pendiente
            ? 'No se recibió la confirmación. Reintenta esta misma venta; el servidor evita registrarla dos veces.'
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _detalle(Venta venta) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Venta #${venta.id}'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vendedor: ${venta.vendedor}'),
              Text('Código interno: ${venta.codigoVendedor}'),
              Text(DateTime.parse(venta.fecha).toLocal().toString()),
              const Divider(),
              for (final d in venta.detalles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${d['nombre']} · ${d['codigo']}\n${d['cantidad']} ${d['unidad']} × ${_importe(d['precioCentavos'] as int)}\nLote: ${(d['lote'] as String).isEmpty ? 'Sin lote registrado' : d['lote']}',
                  ),
                ),
              Text(
                'Total: ${_importe(venta.totalCentavos)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final permitido = widget.store.usuario?.puedeVender ?? false;
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        bottomNavigationBar: StockGoBottomNavigation(
          enabled: !_guardando && !_pendiente,
          store: widget.store,
          current: StockGoModule.ventas,
        ),
        appBar: AppBar(
          leading: StockGoModuleMenu(
            enabled: !_guardando && !_pendiente,
            store: widget.store,
            current: StockGoModule.ventas,
          ),
          title: const Text('Ventas'),
          actions: [
            IconButton(
              onPressed: _guardando || _carrito.isNotEmpty ? null : _cargar,
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: !permitido
            ? const Center(
                child: Text('Los invitados no pueden registrar ventas.'),
              )
            : _cargando
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 950),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [StockGoTheme.navy, StockGoTheme.teal],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const StockGoIconBadge(
                              icon: Icons.point_of_sale_rounded,
                              size: 54,
                              onDark: true,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Vende con el inventario al día',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.store.nombreNegocio,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: ListTile(
                          leading: const StockGoIconBadge(
                            icon: Icons.badge_outlined,
                            size: 40,
                          ),
                          title: Text(widget.store.usuario!.nombreCompleto),
                          subtitle: Text(
                            'Código: ${widget.store.usuario!.codigoInterno} · Usuario: ${widget.store.usuario!.nombre}',
                          ),
                          trailing: widget.store.usuario!.perfilCompleto
                              ? const Icon(Icons.verified_user_outlined)
                              : TextButton(
                                  onPressed: () async {
                                    await showDialog<void>(
                                      context: context,
                                      builder: (_) => PerfilPersonalDialog(
                                        store: widget.store,
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('Completar mis datos'),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nueva venta',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La cantidad corresponde a la unidad registrada: botella, caja, juego o unidad. El precio se toma del inventario.',
                      ),
                      const SizedBox(height: 16),
                      for (final l in _carrito.entries)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _producto(l.key).nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Lote: ${_producto(l.key).ficha['lote']?.isNotEmpty == true ? _producto(l.key).ficha['lote'] : 'Sin lote registrado'} · Disponible: ${_producto(l.key).cantidad}',
                                ),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: _guardando || _pendiente
                                          ? null
                                          : () => setState(() {
                                              if (l.value == 1) {
                                                _carrito.remove(l.key);
                                              } else {
                                                _carrito[l.key] = l.value - 1;
                                              }
                                              _solicitud = _nuevaSolicitud();
                                            }),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _guardando || _pendiente
                                          ? null
                                          : () => _cantidad(l.key),
                                      child: Text('${l.value} · Cantidad'),
                                    ),
                                    IconButton(
                                      onPressed:
                                          _guardando ||
                                              _pendiente ||
                                              l.value >=
                                                  _producto(l.key).cantidad
                                          ? null
                                          : () => setState(() {
                                              _carrito[l.key] = l.value + 1;
                                              _solicitud = _nuevaSolicitud();
                                            }),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                    Text(
                                      _importe(
                                        (_producto(l.key).precio * 100)
                                                .round() *
                                            l.value,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _guardando || _pendiente ? null : _agregar,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Agregar producto a la venta'),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        child: Text(
                          'Total: ${_importe(_total)}',
                          key: ValueKey(_total),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _guardando || _carrito.isEmpty
                            ? null
                            : _confirmar,
                        style: FilledButton.styleFrom(
                          backgroundColor: StockGoTheme.green,
                        ),
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _guardando
                              ? 'Registrando…'
                              : _pendiente
                              ? 'Reintentar confirmación'
                              : 'Confirmar venta',
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.store.usuario!.puedeAdministrar
                            ? 'Ventas del negocio'
                            : 'Mis ventas',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Últimas 100 ventas. El historial conserva precios y lotes originales.',
                      ),
                      if (_ventas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Todavía no hay ventas registradas.'),
                        ),
                      for (final venta in _ventas)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text(
                              'Venta #${venta.id} · ${_importe(venta.totalCentavos)}',
                            ),
                            subtitle: Text(
                              '${venta.vendedor} · ${DateTime.parse(venta.fecha).toLocal().toString().substring(0, 16)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _detalle(venta),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
