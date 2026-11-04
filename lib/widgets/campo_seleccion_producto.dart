import 'package:flutter/material.dart';

/// Mantiene valores existentes y ofrece captura libre para etiquetas no listadas.
class CampoSeleccionProducto extends StatefulWidget {
  const CampoSeleccionProducto({
    super.key,
    required this.controller,
    required this.opciones,
    required this.etiqueta,
    required this.ayuda,
    required this.enabled,
    this.obligatorio = false,
  });
  final TextEditingController controller;
  final List<String> opciones;
  final String etiqueta, ayuda;
  final bool enabled, obligatorio;
  @override
  State<CampoSeleccionProducto> createState() => _CampoSeleccionProductoState();
}

class _CampoSeleccionProductoState extends State<CampoSeleccionProducto> {
  bool _manual = false;
  @override
  Widget build(BuildContext context) {
    final actual = widget.controller.text;
    final opciones = {
      ...widget.opciones,
      if (actual.isNotEmpty && !_manual) actual,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(
            '${widget.etiqueta}_${_manual ? 'manual' : actual}_${widget.opciones.join()}',
          ),
          initialValue: _manual
              ? '__otro'
              : actual.isEmpty
              ? null
              : actual,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: widget.etiqueta,
            helperText: widget.ayuda,
            helperMaxLines: 3,
          ),
          items: [
            for (final opcion in opciones)
              DropdownMenuItem(
                value: opcion,
                child: Text(opcion, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem(
              value: '__otro',
              child: Text('Otro / combinación (escribir)'),
            ),
          ],
          onChanged: !widget.enabled
              ? null
              : (value) => setState(() {
                  _manual = value == '__otro';
                  widget.controller.text = _manual ? '' : value ?? '';
                }),
          validator: (_) =>
              widget.obligatorio && widget.controller.text.trim().isEmpty
              ? 'Selecciona una opción o escribe el valor de la etiqueta.'
              : null,
        ),
        if (_manual)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: widget.controller,
              enabled: widget.enabled,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Valor de la etiqueta / ficha técnica',
              ),
              validator: (value) =>
                  widget.obligatorio && (value ?? '').trim().isEmpty
                  ? 'Escribe el valor.'
                  : null,
            ),
          ),
      ],
    );
  }
}
