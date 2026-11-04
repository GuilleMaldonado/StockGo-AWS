import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';

class AccesoNegocioDialog extends StatefulWidget {
  const AccesoNegocioDialog({super.key, required this.store});
  final StockGoStore store;
  @override
  State<AccesoNegocioDialog> createState() => _AccesoNegocioDialogState();
}

class _AccesoNegocioDialogState extends State<AccesoNegocioDialog> {
  final _form = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _ocupado = false;
  bool _mostrarPassword = false;
  String? _error;
  @override
  void dispose() {
    _codigo.dispose();
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar({bool soloConectar = false}) async {
    if (_ocupado) return;
    if (soloConectar) {
      if (_codigo.text.trim().isEmpty) {
        setState(
          () => _error =
              'Pega el código de conexión que te compartió el administrador.',
        );
        return;
      }
    } else if (!_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (soloConectar) {
        await widget.store.conectarConCodigo(_codigo.text);
      } else {
        await widget.store.entrarConCodigo(
          _codigo.text,
          _usuario.text,
          _password.text,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = e is StockGoException
            ? e.mensaje
            : 'No se pudo acceder al negocio.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      title: const Text('Conectarme a un negocio'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa el código que te compartió el administrador y tu cuenta de ese negocio. StockGo encuentra el servidor automáticamente. Mantén el dispositivo maestro encendido y conectado a la misma red.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('codigo_negocio_conexion'),
                  controller: _codigo,
                  enabled: !_ocupado,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Código de conexión del negocio',
                    hintText: 'SG1-…',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa el código del negocio.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('usuario_negocio_conexion'),
                  controller: _usuario,
                  enabled: !_ocupado,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuario del negocio',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresa tu usuario.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('password_negocio_conexion'),
                  controller: _password,
                  enabled: !_ocupado,
                  obscureText: !_mostrarPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: _ocupado
                          ? null
                          : () => setState(
                              () => _mostrarPassword = !_mostrarPassword,
                            ),
                      icon: Icon(
                        _mostrarPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Ingresa tu contraseña.' : null,
                  onFieldSubmitted: (_) => _entrar(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_ocupado)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _ocupado
                      ? null
                      : () => _entrar(soloConectar: true),
                  child: const Text(
                    'Conectar para crear cuenta o entrar como invitado',
                  ),
                ),
                const Text(
                  'El código identifica al negocio. Los permisos dependen de tu cuenta.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _ocupado ? null : _entrar,
          child: const Text('Conectar e iniciar sesión'),
        ),
      ],
    ),
  );
}
