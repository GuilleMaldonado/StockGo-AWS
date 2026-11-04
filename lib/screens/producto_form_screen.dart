import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/imagen_picker.dart';
import '../services/imagen_producto.dart';

import '../data/stockgo_store.dart';
import '../models/producto.dart';
import '../models/ficha_producto.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/producto_imagen.dart';
import '../widgets/ficha_tecnica_form.dart';
import '../widgets/cerrar_sesion_button.dart';

class ProductoFormScreen extends StatefulWidget {
  const ProductoFormScreen({
    super.key,
    required this.store,
    this.producto,
    this.seleccionarImagen,
  });
  final StockGoStore store;
  final Producto? producto;
  final Future<Uint8List?> Function()? seleccionarImagen;
  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _codigo;
  late final TextEditingController _precio;
  late final TextEditingController _cantidad;
  Uint8List? _imagen;
  String _categoria = 'Repuesto';
  final _ficha = <String, TextEditingController>{};
  final _costo = TextEditingController();
  final _stockMinimo = TextEditingController();
  bool _guardando = false;
  bool _seleccionando = false;
  bool _procesandoImagen = false;
  String? _error;
  bool get _ocupado => _guardando || _seleccionando;
  final _secciones = List.generate(4, (_) => GlobalKey());

  void _irSeccion(int indice) {
    final destino = _secciones[indice].currentContext;
    if (destino != null) {
      Scrollable.ensureVisible(
        destino,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        alignment: .05,
      );
    }
  }

  bool _validarFormulario() {
    final errores = _formKey.currentState!.validateGranularly();
    if (errores.isEmpty) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && errores.first.mounted) {
        Scrollable.ensureVisible(
          errores.first.context,
          duration: const Duration(milliseconds: 300),
          alignment: .2,
        );
      }
    });
    return false;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _codigo = TextEditingController(text: p?.codigo ?? '');
    _precio = TextEditingController(text: p?.precio.toString() ?? '');
    _cantidad = TextEditingController(text: p?.cantidad.toString() ?? '');
    _imagen = p?.imagen;
    _categoria = p?.categoria ?? 'Repuesto';
    _costo.text = (p?.costo ?? 0).toString();
    _stockMinimo.text = (p?.stockMinimo ?? 0).toString();
    for (final campo in camposProducto) {
      _ficha[campo.clave] = TextEditingController(
        text: p?.ficha[campo.clave] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _ficha.values) {
      controller.dispose();
    }
    _costo.dispose();
    _stockMinimo.dispose();
    _nombre.dispose();
    _codigo.dispose();
    _precio.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _subirImagen() async {
    if (_ocupado) return;
    setState(() {
      _seleccionando = true;
      _error = null;
    });
    try {
      final bytes =
          await (widget.seleccionarImagen ?? seleccionarImagenProducto)();
      if (bytes == null || !mounted) return;
      setState(() => _procesandoImagen = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final imagen = await prepararImagenProducto(bytes)
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _imagen = imagen);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StockGoException
              ? e.mensaje
              : e is TimeoutException
              ? 'La imagen tardó demasiado. La aplicación sigue disponible; intenta con un JPG o PNG más pequeño.'
              : e is FormatException
              ? e.message
              : e is PlatformException
              ? 'No se pudo abrir la galería. Revisa los permisos de fotos de StockGo en el dispositivo.'
              : e is MissingPluginException
              ? 'Reinicia completamente StockGo para activar el selector de fotos.'
              : 'No se pudo seleccionar la imagen. Intenta abrir StockGo en Chrome o en la app instalada.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _seleccionando = false;
          _procesandoImagen = false;
        });
      }
    }
  }

  double? _leerPrecio(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _guardar() async {
    if (_ocupado || !_validarFormulario()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.store.guardarProducto(
        Producto(
          id: widget.producto?.id,
          nombre: _nombre.text,
          codigo: _codigo.text,
          precio: _leerPrecio(_precio.text)!,
          cantidad: int.parse(_cantidad.text.trim()),
          imagen: _imagen,
          categoria: _categoria,
          costo: _leerPrecio(_costo.text)!,
          stockMinimo: int.parse(_stockMinimo.text),
          ficha: {
            for (final entry in _ficha.entries.where(
              (entry) =>
                  camposParaCategoria(_categoria)
                      .any((campo) => campo.clave == entry.key),
            ))
              entry.key: entry.value.text.trim(),
          },
        ),
      );
      if (!mounted) return;
      setState(() => _guardando = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e is StockGoException
              ? e.mensaje
              : 'No se pudo guardar el producto. Intenta nuevamente.';
        });
      }
    }
  }

  Widget _tarjeta(
    int indice,
    String titulo,
    String ayuda,
    IconData icono,
    List<Widget> campos,
  ) => Card(
    key: _secciones[indice],
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: StockGoTheme.teal.withValues(alpha: .1),
                child: Icon(icono, color: StockGoTheme.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      ayuda,
                      style: const TextStyle(color: StockGoTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...campos,
        ],
      ),
    ),
  );

  Widget _numero(
    TextEditingController controller,
    String etiqueta,
    String ayuda, {
    bool entero = false,
  }) => TextFormField(
    controller: controller,
    enabled: !_ocupado,
    keyboardType: TextInputType.numberWithOptions(decimal: !entero),
    inputFormatters: entero ? [FilteringTextInputFormatter.digitsOnly] : [],
    decoration: InputDecoration(
      labelText: etiqueta,
      helperText: ayuda,
      helperMaxLines: 2,
      prefixIcon: Icon(
        entero ? Icons.inventory_2_outlined : Icons.payments_outlined,
      ),
    ),
    validator: (v) {
      if (entero) {
        final n = int.tryParse((v ?? '').trim());
        return n == null || n < 0 || n > 2147483647
            ? 'Ingresa una cantidad entera mayor o igual a cero.'
            : null;
      }
      final n = _leerPrecio(v ?? '');
      if (n == null || !n.isFinite || n < 0 || n > 1000000000) {
        return 'Ingresa un precio válido mayor o igual a cero.';
      }
      if ((n * 100 - (n * 100).round()).abs() > .00001) {
        return 'Usa hasta dos decimales.';
      }
      if (controller == _precio && n < (_leerPrecio(_costo.text) ?? 0)) {
        return 'La venta no puede ser menor al precio de compra.';
      }
      return null;
    },
  );

  Widget _columnas(List<Widget> campos) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 18,
      runSpacing: 20,
      children: [
        for (final campo in campos)
          SizedBox(
            width: constraints.maxWidth >= 620
                ? (constraints.maxWidth - 18) / 2
                : constraints.maxWidth,
            child: campo,
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!(widget.store.usuario?.puedeAdministrar ?? false)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Acceso restringido')),
        body: const Center(
          child: Text('Solo el administrador puede modificar productos.'),
        ),
      );
    }
    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.producto == null ? 'Agregar producto' : 'Editar producto',
          ),
          actions: [
            CerrarSesionButton(store: widget.store, enabled: !_ocupado),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: StockGoTheme.line)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _ocupado ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _ocupado ? null : _guardar,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          _guardando ? 'Guardando…' : 'Guardar producto',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            const Text(
                              '¿Qué producto vas a registrar?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Primero elige su categoría. Después completa datos, precios y la ficha del fabricante.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 18),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final categoria in categoriasProducto)
                                  ChoiceChip(
                                    label: Text(categoria),
                                    avatar: Icon(
                                      iconoCategoria(categoria),
                                      size: 18,
                                    ),
                                    selected: _categoria == categoria,
                                    onSelected: _ocupado
                                        ? null
                                        : (_) => setState(
                                            () => _categoria = categoria,
                                          ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entrada in [
                            '1 · Datos',
                            '2 · Precios y stock',
                            '3 · Ficha técnica',
                            '4 · Imagen',
                          ].asMap().entries)
                            ActionChip(
                              label: Text(entrada.value),
                              onPressed: () => _irSeccion(entrada.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _tarjeta(
                        0,
                        '1 · Identifica el producto',
                        'Nombre comercial y código de inventario únicos.',
                        Icons.label_outline,
                        [
                          _columnas([
                            TextFormField(
                              controller: _nombre,
                              enabled: !_ocupado,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del producto',
                                hintText:
                                    'Ejemplo: Aceite Mobil 5W-30 de 1 litro',
                                counterText: '',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Escribe el nombre del producto.'
                                  : null,
                            ),
                            TextFormField(
                              controller: _codigo,
                              enabled: !_ocupado,
                              maxLength: 50,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Código de inventario',
                                hintText: 'Ejemplo: MOB-5W30-L001',
                                helperText:
                                    'Usa un código diferente para cada lote.',
                                counterText: '',
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Escribe un código único.'
                                  : null,
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _tarjeta(
                        1,
                        '2 · Precios y existencias',
                        'Compra y venta deben corresponder a la misma unidad.',
                        Icons.payments_outlined,
                        [
                          _columnas([
                            _numero(
                              _precio,
                              'Precio de venta',
                              'Lo que paga el cliente por una unidad.',
                            ),
                            _numero(
                              _cantidad,
                              'Cantidad disponible',
                              'Cuántas botellas, cajas, juegos o unidades tienes.',
                              entero: true,
                            ),
                            _numero(
                              _costo,
                              'Precio de compra por unidad',
                              'Lo que te cuesta comprar esa misma unidad.',
                            ),
                            _numero(
                              _stockMinimo,
                              'Avisar cuando el stock llegue a',
                              'Cantidad mínima para planificar la reposición.',
                              entero: true,
                            ),
                          ]),
                          const SizedBox(height: 16),
                          ListenableBuilder(
                            listenable: Listenable.merge([_precio, _costo]),
                            builder: (context, _) {
                              final venta = _leerPrecio(_precio.text),
                                  compra = _leerPrecio(_costo.text);
                              if (venta == null ||
                                  compra == null ||
                                  !venta.isFinite ||
                                  !compra.isFinite) {
                                return const Text(
                                  'Ejemplo: compras una botella a 70 y la vendes a 100. Diferencia por botella: 30.',
                                  style: TextStyle(color: StockGoTheme.muted),
                                );
                              }
                              final diferencia = venta - compra;
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color:
                                      (diferencia < 0
                                              ? StockGoTheme.yellow
                                              : StockGoTheme.green)
                                          .withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  diferencia < 0
                                      ? 'Revisa tus precios: la venta está por debajo de la compra.'
                                      : 'Diferencia por unidad: ${diferencia.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        key: _secciones[2],
                        child: FichaTecnicaForm(
                          categoria: _categoria,
                          controllers: _ficha,
                          costo: _costo,
                          stockMinimo: _stockMinimo,
                          enabled: !_ocupado,
                          mostrarCategoria: false,
                          mostrarCompra: false,
                          onCategoria: (value) =>
                              setState(() => _categoria = value),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _tarjeta(
                        3,
                        '4 · Fotografía del producto',
                        'Opcional. Ayuda al equipo a reconocerlo al vender.',
                        Icons.photo_outlined,
                        [
                          if (_procesandoImagen)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 10),
                                  Text('Optimizando la fotografía…'),
                                ],
                              ),
                            )
                          else
                            ProductoImagen(
                              imagen: _imagen,
                              height: _imagen == null ? 100 : 180,
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _ocupado ? null : _subirImagen,
                                icon: const Icon(Icons.upload_outlined),
                                label: Text(
                                  _seleccionando
                                      ? (_procesandoImagen
                                            ? 'Procesando imagen…'
                                            : 'Abriendo imagen…')
                                      : 'Subir imagen',
                                ),
                              ),
                              if (_imagen != null)
                                TextButton.icon(
                                  onPressed: _ocupado
                                      ? null
                                      : () => setState(() => _imagen = null),
                                  icon: const Icon(Icons.close),
                                  label: const Text('Quitar imagen'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'JPG, PNG, WebP o BMP · Hasta 20 MB. Se optimiza automáticamente.',
                            style: TextStyle(
                              color: StockGoTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Puedes guardar sin fotografía. Los campos del fabricante deben coincidir con la etiqueta del producto.',
                        style: TextStyle(color: StockGoTheme.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
