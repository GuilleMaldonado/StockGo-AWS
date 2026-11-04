import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../models/usuario.dart';

class RestablecerPasswordDialog extends StatefulWidget {
  const RestablecerPasswordDialog({
    super.key,
    required this.store,
    required this.usuario,
  });
  final StockGoStore store;
  final Usuario usuario;
  @override
  State<RestablecerPasswordDialog> createState() =>
      _RestablecerPasswordDialogState();
}

class _RestablecerPasswordDialogState extends State<RestablecerPasswordDialog> {
  final _password = TextEditingController();
  bool _ocupado = false;
  String? _error;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _restablecer() async {
    if (_password.text.isEmpty) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final temporal = await widget.store.restablecerPassword(
        widget.usuario.id,
        _password.text,
      );
      if (mounted) {
        setState(() => _ocupado = false);
        Navigator.of(context).pop(temporal);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _error = e is StockGoException
              ? e.mensaje
              : 'No se pudo restablecer la cuenta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      title: const Text('Restablecer contraseña'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.usuario.nombreCompleto}\nUsuario: ${widget.usuario.nombre}\nNegocio: ${widget.store.nombreNegocio}',
              ),
              const SizedBox(height: 16),
              const Text(
                'Se cerrarán sus sesiones y se generará una clave temporal válida por 30 minutos. Confirma tu propia contraseña de administrador.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !_ocupado,
                decoration: const InputDecoration(
                  labelText: 'Tu contraseña de administrador',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
          onPressed: _ocupado ? null : _restablecer,
          child: Text(_ocupado ? 'Procesando…' : 'Generar clave temporal'),
        ),
      ],
    ),
  );
}
