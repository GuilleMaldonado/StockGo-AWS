import 'package:flutter/material.dart';

import '../models/producto.dart';

class CantidadVentaDialog extends StatefulWidget {
  const CantidadVentaDialog({
    super.key,
    required this.producto,
    required this.cantidad,
  });
  final Producto producto;
  final int cantidad;
  @override
  State<CantidadVentaDialog> createState() => _CantidadVentaDialogState();
}

class _CantidadVentaDialogState extends State<CantidadVentaDialog> {
  final _form = GlobalKey<FormState>();
  late final _cantidad = TextEditingController(text: '${widget.cantidad}');
  bool _lote = false;
  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('¿Cuánto vas a vender?'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.producto.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Lote: ${widget.producto.ficha['lote']?.isNotEmpty == true ? widget.producto.ficha['lote'] : 'Sin lote registrado'}',
            ),
            Text(
              'Disponible: ${widget.producto.cantidad} ${widget.producto.ficha['unidadVenta'] ?? 'unidades'}',
            ),
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Por unidades')),
                ButtonSegment(value: true, label: Text('Todo el lote')),
              ],
              selected: {_lote},
              onSelectionChanged: (value) => setState(() {
                _lote = value.single;
                _cantidad.text = _lote
                    ? '${widget.producto.cantidad}'
                    : '${widget.cantidad}';
              }),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _cantidad,
              enabled: !_lote,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                helperText: 'Puedes combinar varios productos y lotes en la misma venta.',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n <= 0 || n > widget.producto.cantidad
                    ? 'Ingresa de 1 a ${widget.producto.cantidad}.'
                    : null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Subtotal: ${(((widget.producto.precio * 100).round() * (int.tryParse(_cantidad.text) ?? 0)) / 100).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, int.parse(_cantidad.text));
          }
        },
        child: const Text('Aplicar cantidad'),
      ),
    ],
  );
}
