import '../widgets/stockgo_login_decoration.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../widgets/windows_servidor_dialog.dart';

import '../data/stockgo_store.dart';
import '../theme/stockgo_theme.dart';
import '../widgets/stockgo_design.dart';
import '../widgets/stockgo_inventory_scene.dart';
import 'registro_screen.dart';
import '../widgets/acceso_negocio_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _password = TextEditingController();
  bool _ocupado = false;
  bool _ocultar = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
  }

  Future<void> _cargarNegocios() async {
    try {
      await widget.store.inicializar();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar los negocios.');
      }
    }
  }

  Future<void> _elegirNegocio(int? id) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await widget.store.seleccionarNegocio(id);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StockGoException
              ? e.mensaje
              : 'No se pudo abrir el negocio.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar({bool invitado = false}) async {
    if (_ocupado || (!invitado && !_formKey.currentState!.validate())) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await widget.store.inicializar();
      if (!mounted) return;
      if (invitado) {
        await widget.store.entrarInvitado();
      } else {
        await widget.store.iniciarSesion(_nombre.text, _password.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is StockGoException
            ? e.mensaje
            : 'No se pudo abrir la base de datos local. Intenta nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _conexion() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AccesoNegocioDialog(store: widget.store),
    );
  }

  Future<void> _registrar() async {
    final nombre = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RegistroScreen(store: widget.store)),
    );
    if (!mounted || nombre == null) return;
    _nombre.text = nombre;
    _password.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cuenta creada. Inicia sesión con tu nueva contraseña.'),
      ),
    );
  }

  Widget _presentacion() => Container(
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [StockGoTheme.navy, StockGoTheme.teal, StockGoTheme.blue],
      ),
      boxShadow: [
        BoxShadow(
          color: StockGoTheme.blue.withValues(alpha: .24),
          blurRadius: 40,
          offset: const Offset(0, 20),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const StockGoInventoryScene(height: 210),
        const SizedBox(height: 24),
        const Text(
          'Menos pendientes.\nMás control.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Todo tu inventario en un solo lugar.\nSimple, ordenado y siempre contigo.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFC3DFD9), fontSize: 17, height: 1.6),
        ),
        const SizedBox(height: 24),
        for (final item in [
          'Productos organizados',
          'Acceso según tu rol',
          'Información guardada localmente',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF8BE5C1),
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  InputDecoration _campoLogin(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    fillColor: const Color(0xFFE4F3FD),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(32),
      borderSide: const BorderSide(color: Color(0xFFD3EBFA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(32),
      borderSide: const BorderSide(color: StockGoTheme.teal, width: 2),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(32)),
  );

  Widget _formulario() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 440),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.white],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: StockGoTheme.navy.withValues(alpha: .17),
            blurRadius: 45,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .9),
            blurRadius: 15,
            offset: const Offset(-6, -6),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: StockGoLoginDecoration()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 106, 24, 76),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const StockGoIconBadge(
                        icon: Icons.inventory_2_rounded,
                        color: StockGoTheme.blue,
                        size: 54,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'StockGo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Bienvenido de nuevo',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inicia sesión para continuar con tu negocio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: StockGoTheme.muted),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F8FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.store.conectado
                              ? widget.store.nombreNegocio
                              : 'Modo local · Este dispositivo',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: StockGoTheme.teal,
                          ),
                        ),
                        if (widget.store.conectado)
                          Text(
                            'Conectado al negocio · Accede con tu cuenta',
                            style: const TextStyle(fontSize: 12),
                          ),
                        TextButton.icon(
                          onPressed: _ocupado ? null : _conexion,
                          icon: const Icon(Icons.wifi, size: 18),
                          label: Text(
                            widget.store.conectado
                                ? 'Cambiar conexión'
                                : 'Soy vendedor · Conectarme a un negocio',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!widget.store.conectado &&
                      widget.store.negocios.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey(widget.store.negocioSeleccionado),
                      initialValue: widget.store.negocioSeleccionado ?? 0,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Negocio'),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('Inventario local anterior'),
                        ),
                        for (final negocio in widget.store.negocios)
                          DropdownMenuItem(
                            value: negocio.id,
                            child: Text(
                              negocio.nombre,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _ocupado
                          ? null
                          : (id) => _elegirNegocio(id == 0 ? null : id),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.windows) ...[
                    OutlinedButton.icon(
                      onPressed: _ocupado
                          ? null
                          : () => activarWindowsDesdeNavegador(
                              context,
                              widget.store,
                            ),
                      icon: const Icon(Icons.desktop_windows_outlined),
                      label: const Text('Activar servidor de esta PC'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nombre,
                    enabled: !_ocupado,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: _campoLogin('Usuario', Icons.person_outline),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Ingresa tu usuario.'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _password,
                    enabled: !_ocupado,
                    obscureText: _ocultar,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    decoration: _campoLogin('Contraseña', Icons.lock_outline)
                        .copyWith(
                          suffixIcon: IconButton(
                            tooltip: _ocultar
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () =>
                                setState(() => _ocultar = !_ocultar),
                            icon: Icon(
                              _ocultar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                    onFieldSubmitted: (_) => _entrar(),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Ingresa tu contraseña.'
                        : null,
                  ),
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
                    style: FilledButton.styleFrom(
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: _ocupado ? null : () => _entrar(),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      _ocupado ? 'Preparando acceso…' : 'Iniciar sesión',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _ocupado ? null : () => _entrar(invitado: true),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Continuar como invitado'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      const Text(
                        '¿Nuevo por aquí?',
                        style: TextStyle(color: StockGoTheme.muted),
                      ),
                      TextButton(
                        onPressed: _ocupado ? null : _registrar,
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                  if (_ocupado)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: StockGoTheme.muted,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Cada negocio conserva sus propias cuentas e inventario.',
                          style: TextStyle(
                            color: StockGoTheme.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 960;
          return SingleChildScrollView(
            padding: EdgeInsets.all(ancho ? 32 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - (ancho ? 64 : 48)).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: ancho
                      ? Row(
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 740,
                                ),
                                child: _presentacion(),
                              ),
                            ),
                            const SizedBox(width: 72),
                            Expanded(child: Center(child: _formulario())),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: _formulario(),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
