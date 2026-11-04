import 'package:flutter/material.dart';

import '../data/stockgo_store.dart';
import '../widgets/cerrar_sesion_button.dart';

class CambiarPasswordScreen extends StatefulWidget {
  const CambiarPasswordScreen({
    super.key,
    required this.store,
    this.obligatorio = false,
  });
  final StockGoStore store;
  final bool obligatorio;
  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _repetir = TextEditingController();
  bool _ocupado = false;
  String? _error;
  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await widget.store.cambiarPassword(_actual.text, _nueva.text);
      if (mounted && !widget.obligatorio) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StockGoException
              ? e.mensaje
              : 'No se pudo cambiar la contraseña.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado && !widget.obligatorio,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
        automaticallyImplyLeading: !widget.obligatorio,
        actions: [CerrarSesionButton(store: widget.store, enabled: !_ocupado)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.lock_reset_rounded, size: 64),
              const SizedBox(height: 20),
              Text(
                widget.obligatorio
                    ? 'Protege tu cuenta antes de continuar'
                    : 'Actualiza tu contraseña',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                widget.obligatorio
                    ? 'Ingresa la clave temporal recibida y elige una contraseña propia. Al guardar, la clave temporal dejará de funcionar.'
                    : 'Necesitas tu contraseña actual. Las demás sesiones de esta cuenta dejarán de tener acceso.',
              ),
              const SizedBox(height: 24),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _actual,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      enabled: !_ocupado,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña actual o temporal',
                      ),
                      validator: (v) => (v ?? '').isEmpty
                          ? 'Ingresa tu contraseña actual.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _nueva,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      enabled: !_ocupado,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                      ),
                      validator: (v) =>
                          (v ?? '').length < 8 || (v ?? '').length > 128
                          ? 'Usa de 8 a 128 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _repetir,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      enabled: !_ocupado,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                      ),
                      validator: (v) => v != _nueva.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _ocupado ? null : _guardar,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _ocupado ? 'Guardando…' : 'Guardar contraseña',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
