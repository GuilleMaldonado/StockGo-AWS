import 'package:flutter/material.dart';

import '../widgets/stockgo_design.dart';

import '../data/stockgo_store.dart';
import '../models/usuario.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/cerrar_sesion_button.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _empresa = TextEditingController();
  final _usuario = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  Rol _rol = Rol.vendedor;
  bool _crearNegocio = false;
  final _codigoInicial = TextEditingController();
  final _codigoNegocio = TextEditingController();
  bool _guardando = false;
  bool _ocultar = true;
  String? _error;
  bool get _esAdmin => widget.store.usuario?.puedeAdministrar ?? false;

  @override
  void dispose() {
    _codigoInicial.dispose();
    _codigoNegocio.dispose();
    _empresa.dispose();
    _usuario.dispose();
    _nombres.dispose();
    _apellidos.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (_guardando || !_form.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.store.inicializar();
      if (_crearNegocio && !_esAdmin) {
        await widget.store.crearPropietario(
          _usuario.text,
          _password.text,
          codigoInicial: _codigoInicial.text.trim(),
          nombreNegocio: _empresa.text,
          nombres: _nombres.text,
          apellidos: _apellidos.text,
        );
      } else {
        if (!_esAdmin && !widget.store.conectado) {
          await widget.store.conectarConCodigo(_codigoNegocio.text);
          if (mounted) setState(() {});
        }
        await widget.store.crearUsuario(
          _usuario.text,
          _password.text,
          rol: _esAdmin ? _rol : Rol.vendedor,
          nombres: _nombres.text,
          apellidos: _apellidos.text,
        );
      }
      if (!mounted) return;
      setState(() => _guardando = false);
      final nombre = _usuario.text.trim().toLowerCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, nombre);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e is StockGoException
            ? e.mensaje
            : 'No se pudo crear la cuenta. Intenta nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Scaffold(
      appBar: AppBar(
        title: Text(_esAdmin ? 'Crear usuario' : 'Crear cuenta'),
        actions: [
          if (widget.store.usuario != null)
            CerrarSesionButton(store: widget.store, enabled: !_guardando),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: StockGoIconBadge(
                            icon: Icons.person_add_alt_1_outlined,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _esAdmin
                              ? 'Un nuevo integrante'
                              : 'Empieza con StockGo',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _esAdmin
                              ? 'Identifica a la persona que registrará las ventas. Su código interno se genera automáticamente.'
                              : 'Crea tu cuenta de vendedor para consultar el inventario y registrar ventas.',
                          style: const TextStyle(color: StockGoTheme.muted),
                        ),
                        const SizedBox(height: 24),
                        if (!_esAdmin && !widget.store.conectado) ...[
                          LayoutBuilder(
                            builder: (context, constraints) =>
                                SegmentedButton<bool>(
                                  direction: constraints.maxWidth < 400
                                      ? Axis.vertical
                                      : Axis.horizontal,
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      label: Text('Soy vendedor'),
                                      icon: Icon(Icons.person_outline),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      label: Text('Crear mi negocio'),
                                      icon: Icon(Icons.storefront_outlined),
                                    ),
                                  ],
                                  selected: {_crearNegocio},
                                  onSelectionChanged: _guardando
                                      ? null
                                      : (value) => setState(
                                          () => _crearNegocio = value.single,
                                        ),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _crearNegocio
                                ? 'Serás el administrador. Podrás agregar productos y compartir este inventario desde una PC o un teléfono.'
                                : 'Podrás consultar productos y registrar ventas. El administrador gestiona los productos.',
                            style: const TextStyle(
                              color: StockGoTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_crearNegocio && !widget.store.conectado) ...[
                            TextFormField(
                              controller: _empresa,
                              enabled: !_guardando,
                              maxLength: 100,
                              decoration: const InputDecoration(
                                labelText: 'Nombre de la empresa',
                                helperText: 'Debe ser único entre los negocios de este dispositivo.',
                              ),
                              validator: (v) => (v?.trim().length ?? 0) < 3
                                  ? 'Ingresa el nombre de la empresa (mínimo 3 caracteres).'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_crearNegocio && widget.store.conectado) ...[
                            TextFormField(
                              controller: _codigoInicial,
                              decoration: const InputDecoration(
                                labelText: 'Código inicial del servidor',
                                helperText: 'Se muestra en Compartir inventario dentro de StockGo.',
                              ),
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Ingresa el código del servidor.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                        if (!_esAdmin &&
                            !_crearNegocio &&
                            !widget.store.conectado) ...[
                          TextFormField(
                            key: const ValueKey('codigo_negocio_registro'),
                            controller: _codigoNegocio,
                            enabled: !_guardando,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Código de negocio',
                              hintText: 'SG1-…',
                              helperText: 'El administrador lo copia desde Compartir inventario en el dispositivo maestro.',
                              helperMaxLines: 3,
                            ),
                            validator: (v) =>
                                (v ?? '').trim().startsWith('SG1-') ? null : 'Pega el código completo del negocio al que perteneces.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (widget.store.conectado) ...[
                          Text(
                            'Tu cuenta se creará en: ${widget.store.nombreNegocio}',
                            style: const TextStyle(
                              color: StockGoTheme.teal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          key: const ValueKey('registro_nombres'),
                          controller: _nombres,
                          enabled: !_guardando,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombres',
                            hintText: 'Ejemplo: Ana María',
                          ),
                          validator: Usuario.validarNombre,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const ValueKey('registro_apellidos'),
                          controller: _apellidos,
                          enabled: !_guardando,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Apellidos',
                            hintText: 'Ejemplo: Pérez López',
                          ),
                          validator: Usuario.validarNombre,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usuario,
                          key: const ValueKey('registro_usuario'),
                          enabled: !_guardando,
                          maxLength: 40,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Usuario de acceso',
                            helperText: 'Solo letras, puntos o guiones. Ejemplo: ana.perez',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              RegExp(r'^[a-zA-Z._-]{3,40}$')
                                  .hasMatch((v ?? '').trim())
                              ? null
                              : 'Usa de 3 a 40 letras, puntos o guiones. Sin números ni espacios.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          enabled: !_guardando,
                          obscureText: _ocultar,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            helperText: 'Entre 8 y 128 caracteres.',
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _ocultar = !_ocultar),
                              tooltip: _ocultar
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(
                                _ocultar
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) =>
                              (v?.length ?? 0) >= 8 && (v?.length ?? 0) <= 128
                              ? null
                              : 'La contraseña debe tener entre 8 y 128 caracteres.',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmacion,
                          enabled: !_guardando,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                          ),
                          onFieldSubmitted: (_) => _crear(),
                          validator: (v) => v == _password.text
                              ? null
                              : 'Las contraseñas no coinciden.',
                        ),
                        if (_esAdmin) ...[
                          const SizedBox(height: 20),
                          DropdownButtonFormField<Rol>(
                            initialValue: _rol,
                            decoration: const InputDecoration(labelText: 'Rol'),
                            items: [Rol.vendedor, Rol.administrador]
                                .map(
                                  (rol) => DropdownMenuItem(
                                    value: rol,
                                    child: Text(rol.etiqueta),
                                  ),
                                )
                                .toList(),
                            onChanged: _guardando
                                ? null
                                : (rol) => setState(() => _rol = rol!),
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _guardando ? null : _crear,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(
                            _guardando
                                ? 'Creando cuenta…'
                                : (_esAdmin ? 'Crear usuario' : 'Crear cuenta'),
                          ),
                        ),
                        if (_guardando)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
