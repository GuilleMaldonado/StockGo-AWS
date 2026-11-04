import '../widgets/stockgo_product_card.dart';
import '../widgets/stockgo_bottom_navigation.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../models/producto.dart';
import '../models/ficha_producto.dart';
import '../widgets/producto_imagen.dart';
import '../widgets/cerrar_sesion_button.dart';
import 'producto_form_screen.dart';
import 'ventas_screen.dart';
import '../widgets/stockgo_design.dart';
import '../widgets/stockgo_module_menu.dart';

class ProductosScreen extends StatefulWidget {
  const ProductosScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  final _busqueda = TextEditingController();
  Timer? _debounce;
  Timer? _actualizacion;
  List<Producto> _productos = [];
  bool _cargando = true;
  String? _categoria;
  bool _incluirInactivos = false;
  bool _desactivando = false;
  String? _error;
  int _consulta = 0;
  bool get _esAdmin => widget.store.usuario?.puedeAdministrar ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.store.conectado) {
      _actualizacion = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted &&
            !_cargando &&
            !_desactivando &&
            (ModalRoute.of(context)?.isCurrent ?? false)) {
          _cargar();
        }
      });
    }
    _cargar();
  }

  @override
  void dispose() {
    _actualizacion?.cancel();
    _debounce?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final productos = await widget.store.buscarProductos(
        busqueda: _busqueda.text,
        incluirInactivos: _incluirInactivos,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _productos = productos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _cargando = false;
        _error = e is StockGoException
            ? e.mensaje
            : 'No se pudo cargar el inventario.';
      });
    }
  }

  void _buscar(String value) {
    _debounce?.cancel();
    // Invalida cualquier resultado anterior mientras se escribe.
    _consulta++;
    setState(() => _cargando = true);
    _debounce = Timer(const Duration(milliseconds: 250), _cargar);
  }

  Future<void> _abrirFormulario([Producto? producto]) async {
    if (!_esAdmin) return;
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductoFormScreen(store: widget.store, producto: producto),
      ),
    );
    if (!mounted || guardado != true) return;
    // Un producto nuevo siempre aparece, aunque hubiese una búsqueda anterior.
    if (producto == null) {
      _busqueda.clear();
      _categoria = null;
    }
    _debounce?.cancel();
    await _cargar();
    if (mounted) {
      _mensaje(
        producto == null ? 'Producto registrado.' : 'Producto actualizado.',
      );
    }
  }

  void _mensaje(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _detalle(Producto producto) async {
    final accion = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(producto.nombre),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (producto.imagen != null) ...[
                ProductoImagen(
                  imagen: producto.imagen,
                  width: 320,
                  height: 190,
                ),
                const SizedBox(height: 16),
              ],
              Text('Código: ${producto.codigo}'),
              const SizedBox(height: 8),
              Text('Precio: ${producto.precio.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Cantidad disponible: ${producto.cantidad}'),
              const SizedBox(height: 8),
              Text('Categoría: ${producto.categoria}'),
              for (final campo in camposParaCategoria(producto.categoria))
                if ((producto.ficha[campo.clave] ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${campo.etiqueta}: ${producto.ficha[campo.clave]}',
                    ),
                  ),
              if (widget.store.usuario?.puedeAdministrar == true) ...[
                Text('Costo: ${producto.costo.toStringAsFixed(2)}'),
                Text('Stock mínimo: ${producto.stockMinimo}'),
              ],
              Text('Estado: ${producto.activo ? 'Activo' : 'Inactivo'}'),
              if (!producto.activo)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Este producto se conserva como historial.'),
                ),
            ],
          ),
        ),
        actions: [
          if (widget.store.usuario?.puedeVender == true &&
              producto.activo &&
              producto.cantidad > 0)
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, 'vender'),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Vender'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (_esAdmin && producto.activo) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'desactivar'),
              child: const Text('Desactivar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'editar'),
              child: const Text('Editar'),
            ),
          ],
        ],
      ),
    );
    if (!mounted) return;
    if (accion == 'editar') await _abrirFormulario(producto);
    if (accion == 'desactivar') await _confirmarDesactivacion(producto);
    if (accion == 'vender') await _abrirVenta(producto);
  }

  Future<void> _abrirVenta([Producto? producto]) async {
    if (widget.store.usuario?.puedeVender != true) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            VentasScreen(store: widget.store, productoInicial: producto),
      ),
    );
    if (mounted && widget.store.usuario != null) await _cargar();
  }

  Future<void> _confirmarDesactivacion(Producto producto) async {
    if (!_esAdmin || _desactivando) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar producto'),
        content: Text(
          '¿Deseas desactivar "${producto.nombre}"?\n\n'
          'Dejará de aparecer en el inventario activo. Sus datos se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmado != true) return;
    setState(() => _desactivando = true);
    try {
      await widget.store.desactivarProducto(producto.id!);
      if (!mounted) return;
      await _cargar();
      if (mounted) _mensaje('Producto desactivado. Se conserva su historial.');
    } catch (e) {
      if (mounted) {
        _mensaje(
          e is StockGoException
              ? e.mensaje
              : 'No se pudo desactivar el producto.',
        );
      }
    } finally {
      if (mounted) setState(() => _desactivando = false);
    }
  }

  Widget _contenido() {
    if (_cargando) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _cargar,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_productos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  _busqueda.text.trim().isEmpty
                      ? 'No hay productos para mostrar.'
                      : 'No se encontraron productos.',
                  textAlign: TextAlign.center,
                ),
                if (_esAdmin && _busqueda.text.trim().isEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Pulsa Agregar producto para registrar el primero.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    final visibles = _productos
        .where((p) => _categoria == null || p.categoria == _categoria)
        .toList();
    if (visibles.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No hay productos en esta categoría.')),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = width >= 1000
            ? 4
            : width >= 700
            ? 3
            : width >= 360
            ? 2
            : 1;
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 366 + 150 * (textScale - 1).clamp(0, 2),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => StockGoProductCard(
                producto: visibles[index],
                onTap: _desactivando ? null : () => _detalle(visibles[index]),
              ),
              childCount: visibles.length,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: StockGoBottomNavigation(
      store: widget.store,
      current: StockGoModule.inventario,
    ),
    appBar: AppBar(
      leading: StockGoModuleMenu(
        store: widget.store,
        current: StockGoModule.inventario,
      ),
      title: const Text('Inventario'),
      actions: [
        if (widget.store.usuario?.puedeVender == true)
          IconButton(
            onPressed: () => _abrirVenta(),
            tooltip: 'Nueva venta',
            icon: const Icon(Icons.point_of_sale),
          ),
        CerrarSesionButton(store: widget.store, enabled: !_desactivando),
        IconButton(
          tooltip: 'Actualizar inventario',
          onPressed: _desactivando
              ? null
              : () {
                  _debounce?.cancel();
                  _cargar();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: StockGoSectionHeading(
                          title: 'Catálogo del negocio',
                          subtitle:
                              '${_productos.length} productos · ${widget.store.nombreNegocio}',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _busqueda,
                          onChanged: _buscar,
                          decoration: InputDecoration(
                            labelText: 'Buscar productos',
                            hintText: 'Nombre, código o marca',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _busqueda.clear();
                                _buscar('');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            for (final categoria in <String?>[
                              null,
                              ...categoriasProducto,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  avatar: Icon(
                                    iconoCategoria(categoria),
                                    size: 18,
                                  ),
                                  label: Text(
                                    categoria == null
                                        ? 'Todos'
                                        : pluralCategoria(categoria),
                                  ),
                                  selected: _categoria == categoria,
                                  onSelected: _desactivando
                                      ? null
                                      : (_) => setState(
                                          () => _categoria = categoria,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_esAdmin)
                        SwitchListTile(
                          title: const Text('Mostrar también desactivados'),
                          value: _incluirInactivos,
                          onChanged: _desactivando
                              ? null
                              : (value) {
                                  setState(() => _incluirInactivos = value);
                                  _debounce?.cancel();
                                  _cargar();
                                },
                        ),
                      if (_desactivando) const LinearProgressIndicator(),
                    ],
                  ),
                ),
                _contenido(),
              ],
            ),
          ),
        ),
      ),
    ),
    floatingActionButton: _esAdmin
        ? FloatingActionButton.extended(
            onPressed: _desactivando ? null : () => _abrirFormulario(),
            icon: const Icon(Icons.add),
            label: const Text('Agregar producto'),
          )
        : widget.store.usuario?.puedeVender == true
        ? FloatingActionButton.extended(
            onPressed: () => _abrirVenta(),
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Nueva venta'),
          )
        : null,
  );
}
