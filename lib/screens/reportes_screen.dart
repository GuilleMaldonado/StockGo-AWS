import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../models/venta.dart';
import '../models/resumen_ventas.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/stockgo_module_menu.dart';
import '../widgets/cerrar_sesion_button.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  List<Venta> _ventas = [];
  bool _cargando = true;
  String? _error;
  int _periodo = 30;
  String? _vendedor;
  bool get _admin => widget.store.usuario?.puedeAdministrar == true;
  String _dinero(int centavos) => 'Q ${(centavos / 100).toStringAsFixed(2)}';
  String _identidad(Venta v) => v.codigoVendedor.isEmpty
      ? v.vendedor
      : '${v.vendedor} · ${v.codigoVendedor}';
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final ventas = await widget.store.listarVentas();
      if (mounted) {
        setState(() {
          _ventas = ventas;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is StockGoException ? e.mensaje : 'No se pudo cargar el historial. Revisa la conexión y vuelve a intentar.';
          _cargando = false;
        });
      }
    }
  }

  List<Venta> get _filtradas {
    final ahora = DateTime.now();
    final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
    final desde = inicioHoy.subtract(Duration(days: _periodo - 1));
    return _ventas.where((v) {
      final fecha = DateTime.tryParse(v.fecha)?.toLocal();
      return (_vendedor == null || _identidad(v) == _vendedor) &&
          (_periodo == 0 ||
              (fecha != null &&
                  !fecha.isBefore(desde) &&
                  fecha.isBefore(inicioHoy.add(const Duration(days: 1)))));
    }).toList();
  }

  void _detalle(Venta venta) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Venta #${venta.id}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('Vendió: ${_identidad(venta)}'),
              Text(_fecha(venta)),
              const Divider(height: 32),
              for (final d in venta.detalles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${d['nombre']}'),
                  subtitle: Text(
                    'Código: ${d['codigo']}\nCantidad: ${d['cantidad']} ${d['unidad'] ?? ''}\nLote: ${(d['lote'] as String?)?.isNotEmpty == true ? d['lote'] : 'Sin lote'}\nPrecio unitario: ${_dinero((d['precioCentavos'] as num).toInt())}',
                  ),
                  trailing: Text(
                    _dinero(
                      (d['precioCentavos'] as num).toInt() *
                          (d['cantidad'] as num).toInt(),
                    ),
                  ),
                ),
              const Divider(),
              Text(
                'Total: ${_dinero(venta.totalCentavos)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fecha(Venta venta) {
    final fecha = DateTime.tryParse(venta.fecha)?.toLocal();
    if (fecha == null) return venta.fecha;
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Widget _metrica(String titulo, String valor, IconData icono) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: StockGoTheme.blue),
            const SizedBox(height: 10),
            Text(valor, style: Theme.of(context).textTheme.titleLarge),
            Text(titulo, style: const TextStyle(color: StockGoTheme.muted)),
          ],
        ),
      ),
    ),
  );

  Widget _ranking(
    String titulo,
    Map<String, RendimientoVenta> datos, {
    bool unidades = false,
  }) {
    final ordenados = datos.entries.toList()
      ..sort(
        (a, b) => unidades
            ? b.value.unidades.compareTo(a.value.unidades)
            : b.value.ingreso.compareTo(a.value.ingreso),
      );
    final maximo = ordenados.isEmpty
        ? 0
        : unidades
        ? ordenados.first.value.unidades
        : ordenados.first.value.ingreso;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (ordenados.isEmpty)
              const Text('Todavía no hay ventas en este período.'),
            for (final fila in ordenados.take(unidades ? 10 : ordenados.length))
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      fila.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${fila.value.ventas} ${unidades ? 'apariciones en ventas' : 'ventas'} · ${fila.value.unidades} unidades · ${_dinero(fila.value.ingreso)}',
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: maximo == 0
                          ? 0
                          : (unidades
                                    ? fila.value.unidades
                                    : fila.value.ingreso) /
                                maximo,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ventas = _filtradas;
    final resumen = ResumenVentas(ventas);
    final vendedores = _ventas.map(_identidad).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(
        leading: StockGoModuleMenu(
          store: widget.store,
          current: StockGoModule.reportes,
        ),
        title: const Text('Historial y estadísticas'),
        actions: [
          IconButton(
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          CerrarSesionButton(store: widget.store),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _cargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        widget.store.nombreNegocio,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        _admin
                            ? 'Resultados de tu negocio y rendimiento del equipo.'
                            : 'Tus ventas y resultados personales.',
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<int>(
                        initialValue: _periodo,
                        decoration: const InputDecoration(labelText: 'Período'),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Hoy')),
                          DropdownMenuItem(
                            value: 7,
                            child: Text('Últimos 7 días'),
                          ),
                          DropdownMenuItem(
                            value: 30,
                            child: Text('Últimos 30 días'),
                          ),
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Todo el historial'),
                          ),
                        ],
                        onChanged: (valor) => setState(() => _periodo = valor!),
                      ),
                      if (_admin) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _vendedor,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Vendedor',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todo el equipo'),
                            ),
                            for (final v in vendedores)
                              DropdownMenuItem(
                                value: v,
                                child: Text(v, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setState(() => _vendedor = v),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metrica(
                            'Importe vendido',
                            _dinero(resumen.ingreso),
                            Icons.payments_rounded,
                          ),
                          _metrica(
                            'Ventas completadas',
                            '${resumen.tickets}',
                            Icons.receipt_long_rounded,
                          ),
                          _metrica(
                            'Unidades vendidas',
                            '${resumen.unidades}',
                            Icons.inventory_2_rounded,
                          ),
                          _metrica(
                            'Promedio por venta',
                            _dinero(resumen.ticketPromedio),
                            Icons.insights_rounded,
                          ),
                          if (_admin)
                            _metrica(
                              'Margen bruto estimado',
                              resumen.costosCompletos
                                  ? _dinero(resumen.margenBruto)
                                  : 'Costos incompletos',
                              Icons.trending_up_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unidades según el registro de venta; no equivale a litros ni cajas. El margen bruto no descuenta gastos ni impuestos.',
                      ),
                      const SizedBox(height: 18),
                      _ranking(
                        _admin
                            ? 'Productividad por vendedor'
                            : 'Mi rendimiento',
                        resumen.vendedores,
                      ),
                      const SizedBox(height: 12),
                      _ranking(
                        '10 productos más vendidos por unidades',
                        resumen.productos,
                        unidades: true,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Ventas realizadas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (ventas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No hay ventas para estos filtros.'),
                        ),
                      for (final venta in ventas)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.receipt_long_rounded,
                              color: StockGoTheme.blue,
                            ),
                            title: Text(
                              'Venta #${venta.id} · ${_dinero(venta.totalCentavos)}',
                            ),
                            subtitle: Text(
                              '${_identidad(venta)}\n${_fecha(venta)} · ${venta.detalles.length} productos',
                            ),
                            isThreeLine: true,
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
