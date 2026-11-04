import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../models/usuario.dart';

class PerfilPersonalDialog extends StatefulWidget {
  const PerfilPersonalDialog({super.key, required this.store});
  final StockGoStore store;
  @override
  State<PerfilPersonalDialog> createState() => _PerfilPersonalDialogState();
}

class _PerfilPersonalDialogState extends State<PerfilPersonalDialog> {
  final _form = GlobalKey<FormState>();
  late final _nombres = TextEditingController(
    text: widget.store.usuario?.nombres,
  );
  late final _apellidos = TextEditingController(
    text: widget.store.usuario?.apellidos,
  );
  bool _ocupado = false;
  String? _error;
  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate() || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      await widget.store.completarPerfil(_nombres.text, _apellidos.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      title: const Text('¿Quién registra las ventas?'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Completa tu identidad. Tu usuario y contraseña se conservan.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombres,
                enabled: !_ocupado,
                decoration: const InputDecoration(labelText: 'Nombres'),
                validator: Usuario.validarNombre,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apellidos,
                enabled: !_ocupado,
                decoration: const InputDecoration(labelText: 'Apellidos'),
                validator: Usuario.validarNombre,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _guardar,
          child: Text(_ocupado ? 'Guardando…' : 'Guardar identidad'),
        ),
      ],
    ),
  );
}
