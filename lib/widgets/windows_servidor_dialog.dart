import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/stockgo_store.dart';
import '../network/codigo_negocio.dart';

class _ConexionWindows {
  const _ConexionWindows(this.codigo, this.usuario, this.password);
  final String codigo, usuario, password;
}

Future<void> activarWindowsDesdeNavegador(
  BuildContext context,
  StockGoStore store,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final resultado = await showDialog<_ConexionWindows>(
    context: context,
    builder: (_) => const WindowsServidorDialog(),
  );
  if (resultado == null) return;
  try {
    store.cerrarSesion();
    await store.conectarConCodigo(resultado.codigo);
    await store.iniciarSesion(resultado.usuario, resultado.password);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Servidor Windows activo. Estás conectado al negocio seleccionado.',
        ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e is StockGoException
              ? e.mensaje
              : 'No se pudo conectar con el servidor Windows.',
        ),
      ),
    );
  }
}

class WindowsServidorDialog extends StatefulWidget {
  const WindowsServidorDialog({super.key});
  @override
  State<WindowsServidorDialog> createState() => _WindowsServidorDialogState();
}

class _WindowsServidorDialogState extends State<WindowsServidorDialog> {
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  List<Map<String, dynamic>> _negocios = [];
  int? _id;
  bool _ocupado = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:8079/desktop/businesses'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) throw const FormatException();
      final data = jsonDecode(r.body) as Map;
      final negocios = (data['negocios'] as List)
          .map((n) => (n as Map).cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() {
        _negocios = negocios;
        _id = negocios.isEmpty ? null : negocios.first['id'] as int;
        _ocupado = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = 'Abre la aplicación StockGo para Windows en esta PC y pulsa Reintentar. El navegador usa esa aplicación para alojar el servidor.';
      });
    }
  }

  Future<void> _activar() async {
    if (_id == null || _usuario.text.trim().isEmpty || _password.text.isEmpty) {
      setState(
        () => _error =
            'Selecciona el negocio e ingresa su cuenta de administrador.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final r = await http
          .post(
            Uri.parse('http://127.0.0.1:8079/desktop/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'negocioId': _id,
              'usuario': _usuario.text.trim(),
              'password': _password.text,
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(r.body) as Map;
      if (r.statusCode != 200) {
        throw StockGoException(
          data['error'] as String? ?? 'No se pudo activar el servidor.',
        );
      }
      final codigo = data['codigo'] as String;
      if (CodigoNegocio.leer(codigo).direccion != 'http://127.0.0.1:8081') {
        throw const FormatException();
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _ConexionWindows(codigo, _usuario.text.trim(), _password.text),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _error = e is StockGoException ? e.mensaje : 'No se pudo contactar con StockGo para Windows. Comprueba que sigue abierto.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: AlertDialog(
      title: const Text('Activar servidor en esta PC'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mantén abierta StockGo para Windows. Elige el negocio guardado en esa aplicación y autentícate como su administrador. El navegador se conectará automáticamente al activarlo.',
              ),
              const SizedBox(height: 16),
              if (_ocupado) const LinearProgressIndicator(),
              if (!_ocupado && _negocios.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  key: ValueKey(_id),
                  initialValue: _id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Negocio en Windows',
                  ),
                  items: [
                    for (final n in _negocios)
                      DropdownMenuItem(
                        value: n['id'] as int,
                        child: Text(n['nombre'] as String),
                      ),
                  ],
                  onChanged: (v) => setState(() => _id = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usuario,
                  decoration: const InputDecoration(
                    labelText: 'Usuario administrador',
                  ),
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _activar(),
                ),
              ],
              if (!_ocupado && _negocios.isEmpty && _error == null)
                const Text(
                  'No hay negocios en Windows. Usa Crear cuenta → Crear mi negocio en la aplicación de escritorio y después pulsa Reintentar.',
                ),
              const SizedBox(height: 12),
              const Text(
                'Los datos locales del navegador y del emulador no se transfieren automáticamente a Windows. Selecciona el negocio que realmente vas a compartir.',
                style: TextStyle(fontSize: 12),
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
        TextButton(
          onPressed: _ocupado ? null : _cargar,
          child: const Text('Reintentar'),
        ),
        FilledButton(
          onPressed: _ocupado || _negocios.isEmpty ? null : _activar,
          child: const Text('Activar y conectar'),
        ),
      ],
    ),
  );
}
