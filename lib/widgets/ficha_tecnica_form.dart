import 'package:flutter/material.dart';

import '../models/ficha_producto.dart';
import '../models/opciones_ficha.dart';
import 'campo_seleccion_producto.dart';
import '../theme/stockgo_theme.dart';

IconData iconoCategoria(String categoria) => switch (categoria) {
  'Lubricante' => Icons.water_drop_outlined,
  'Filtro' => Icons.filter_alt_outlined,
  'Aditivo' => Icons.science_outlined,
  'Accesorio' => Icons.electrical_services_outlined,
  _ => Icons.settings_outlined,
};

class FichaTecnicaForm extends StatelessWidget {
  const FichaTecnicaForm({
    super.key,
    required this.categoria,
    required this.controllers,
    required this.costo,
    required this.stockMinimo,
    required this.enabled,
    required this.onCategoria,
    this.mostrarCategoria = true,
    this.mostrarCompra = true,
  });
  final String categoria;
  final Map<String, TextEditingController> controllers;
  final TextEditingController costo;
  final TextEditingController stockMinimo;
  final bool enabled;
  final ValueChanged<String> onCategoria;
  final bool mostrarCategoria;
  final bool mostrarCompra;

  Widget _campo(CampoProducto campo) {
    final opciones = opcionesCampo(
      campo.clave,
      categoria,
      controllers['tipo']!.text,
    );
    if (opciones.isNotEmpty) {
      return CampoSeleccionProducto(
        key: ValueKey('ficha_${campo.clave}'),
        controller: controllers[campo.clave]!,
        opciones: opciones,
        etiqueta: campo.etiqueta,
        ayuda: campo.clave == 'viscosidadSAE'
            ? 'Selecciona el grado del envase. Motor y engranajes usan escalas distintas; revísalo al cambiar el tipo.'
            : campo.ejemplo,
        enabled: enabled,
        obligatorio: [
          'tipo',
          'unidadVenta',
          'viscosidadSAE',
        ].contains(campo.clave),
      );
    }
    return TextFormField(
      key: ValueKey('ficha_${campo.clave}'),
      controller: controllers[campo.clave],
      enabled: enabled,
      maxLength: ['compatibilidad', 'descripcion'].contains(campo.clave)
          ? 2000
          : 200,
      maxLines: ['compatibilidad', 'descripcion'].contains(campo.clave) ? 4 : 1,
      minLines: campo.clave == 'compatibilidad' ? 2 : 1,
      decoration: InputDecoration(
        labelText: campo.etiqueta,
        helperText: campo.ejemplo,
        helperMaxLines: 3,
        counterText: '',
      ),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (['marca', 'tipo', 'unidadVenta'].contains(campo.clave) &&
            value.isEmpty) {
          return 'Este campo es obligatorio.';
        }
        if (categoria == 'Lubricante' &&
            campo.clave == 'viscosidadSAE' &&
            value.isEmpty) {
          return 'Indica la viscosidad de la etiqueta.';
        }
        if (['Lubricante', 'Aditivo'].contains(categoria) &&
            campo.clave == 'lote' &&
            value.isEmpty) {
          return 'Registra el lote del fabricante.';
        }
        if (campo.clave == 'vencimiento' && value.isNotEmpty) {
          final fecha = DateTime.tryParse(value);
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
              fecha == null ||
              fecha.toIso8601String().substring(0, 10) != value) {
            return 'Usa una fecha válida AAAA-MM-DD.';
          }
        }
        return null;
      },
    );
  }

  Widget _campos(List<CampoProducto> campos) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth >= 560
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 18,
        children: [
          for (final campo in campos)
            SizedBox(
              width: campo.clave == 'compatibilidad'
                  ? constraints.maxWidth
                  : width,
              child: _campo(campo),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final visibles = camposParaCategoria(categoria);
    final esenciales = visibles
        .where(
          (c) =>
              ['marca', 'tipo', 'unidadVenta'].contains(c.clave) ||
              (['Lubricante', 'Aditivo'].contains(categoria) &&
                  c.clave == 'lote'),
        )
        .toList();
    final opcionales = visibles
        .where(
          (c) =>
              c.grupo == 'general' &&
              !esenciales.contains(c) &&
              ![
                'marca',
                'tipo',
                'unidadVenta',
                'numeroParte',
                'referenciaOEM',
              ].contains(c.clave),
        )
        .toList();
    final tecnicos = visibles
        .where((c) => !esenciales.contains(c) && !opcionales.contains(c))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mostrarCategoria
                      ? '¿Qué vas a registrar?'
                      : 'Marca y presentación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'La categoría adapta los campos técnicos del producto.',
                  style: TextStyle(color: StockGoTheme.muted),
                ),
                const SizedBox(height: 16),
                if (mostrarCategoria)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categoriasProducto)
                        ChoiceChip(
                          avatar: Icon(iconoCategoria(c), size: 18),
                          label: Text(c),
                          selected: categoria == c,
                          onSelected: enabled ? (_) => onCategoria(c) : null,
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                _campos(esenciales),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: StockGoTheme.teal.withValues(alpha: .25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2EF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        iconoCategoria(categoria),
                        color: StockGoTheme.teal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tituloFichaCategoria(categoria),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  descripcionFichaCategoria(categoria),
                  style: const TextStyle(color: StockGoTheme.muted),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controllers['tipo']!,
                  builder: (context, value, child) => _campos(tecnicos),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: ExpansionTile(
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            leading: const Icon(
              Icons.inventory_2_outlined,
              color: StockGoTheme.teal,
            ),
            title: const Text('Presentación y logística'),
            subtitle: const Text('Descripción, proveedor, lote y ubicación'),
            childrenPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [_campos(opcionales)],
          ),
        ),
        if (mostrarCompra) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Compra y reposición',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: costo,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Precio de compra por unidad',
                      helperText: 'Usa la misma unidad que el precio de venta y hasta dos decimales.',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final n = double.tryParse(
                        (v ?? '').trim().replaceAll(',', '.'),
                      );
                      return n == null ||
                              !n.isFinite ||
                              n < 0 ||
                              n > 1000000000 ||
                              (n * 100 - (n * 100).round()).abs() > .00001
                          ? 'Ingresa un costo válido.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: stockMinimo,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Stock mínimo',
                      helperText:
                          'Cantidad mínima antes de reponer existencias.',
                      prefixIcon: Icon(Icons.low_priority),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return n == null || n < 0 || n > 2147483647
                          ? 'Ingresa un entero válido.'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
