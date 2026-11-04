import '../widgets/stockgo_bottom_navigation.dart';

import 'package:flutter/material.dart';

import '../widgets/stockgo_design.dart';
import '../widgets/stockgo_module_menu.dart';

import 'package:flutter/services.dart';

import '../data/stockgo_store.dart';
import '../models/usuario.dart';
import '../theme/stockgo_theme.dart';
import 'registro_screen.dart';
import 'cambiar_password_screen.dart';
import '../widgets/restablecer_password_dialog.dart';

class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key, required this.store});
  final StockGoStore store;
  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  List<Usuario> _usuarios = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final usuarios = await widget.store.listarUsuarios();
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e is StockGoException
            ? e.mensaje
            : 'No se pudo cargar el equipo.';
      });
    }
  }

  Future<void> _crear() async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RegistroScreen(store: widget.store)),
    );
    if (mounted) await _cargar();
  }

  Future<void> _restablecer(Usuario usuario) async {
    if (usuario.id == widget.store.usuario?.id) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CambiarPasswordScreen(store: widget.store),
        ),
      );
      return;
    }
    final temporal = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          RestablecerPasswordDialog(store: widget.store, usuario: usuario),
    );
    if (!mounted || temporal == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clave temporal generada'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Negocio: ${widget.store.nombreNegocio}\nUsuario: ${usuario.nombre}',
                ),
                const SizedBox(height: 16),
                SelectableText(
                  temporal,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Válida por 30 minutos. Entrégala de forma privada a la persona cuya identidad verificaste. Al ingresar deberá elegir su nueva contraseña. No queda guardada en el historial.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: temporal));
            },
            child: const Text('Copiar clave'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _auditoria() async {
    try {
      final eventos = await widget.store.listarAuditoria();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Historial de seguridad'),
          content: SizedBox(
            width: 550,
            height: 420,
            child: eventos.isEmpty
                ? const Center(
                    child: Text(
                      'Todavía no hay cambios de contraseña registrados.',
                    ),
                  )
                : ListView(
                    children: [
                      for (final e in eventos)
                        ListTile(
                          title: Text(
                            e['accion'] == 'restablecer_password'
                                ? 'Restablecimiento de contraseña'
                                : 'Cambio de contraseña',
                          ),
                          subtitle: Text(
                            'Responsable: ${e['actor']}\nCuenta: ${e['objetivo']}\n${DateTime.tryParse(e['fecha'] as String)?.toLocal() ?? e['fecha']}',
                          ),
                          isThreeLine: true,
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StockGoException
                  ? e.mensaje
                  : 'No se pudo cargar el historial.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _invitar() async {
    try {
      final codigos = await widget.store.codigosInvitacion();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Invitar a ${widget.store.nombreNegocio}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Copia la invitación y compártela con tu vendedor. En StockGo debe elegir Conectarme a un negocio y pegar el código. Ingresa su usuario y contraseña en ese formulario; si no tiene cuenta, elige la opción para crearla.',
                  ),
                  const SizedBox(height: 16),
                  for (final entrada in codigos.entries) ...[
                    Text(
                      entrada.key.contains('127.0.0.1') ||
                              entrada.key.contains('localhost')
                          ? 'Navegador de esta misma PC'
                          : 'Otro dispositivo en la misma Wi-Fi',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      entrada.key,
                      style: const TextStyle(color: StockGoTheme.muted),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      entrada.value,
                      style: const TextStyle(fontSize: 12),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                'Te invito al negocio ${widget.store.nombreNegocio} en StockGo. Conéctate a la misma Wi-Fi, abre Conectarme a un negocio y pega este código:\n${entrada.value}\nInicia sesión o crea tu cuenta de vendedor.',
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invitación copiada.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copiar invitación'),
                    ),
                    const Divider(),
                  ],
                  const Text(
                    'El código conecta con el negocio; no concede permisos de administrador. El invitado no cuenta como vendedor registrado.',
                    style: TextStyle(color: StockGoTheme.muted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StockGoException
                ? e.mensaje
                : 'No se pudo generar la invitación.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permitido = widget.store.usuario?.puedeAdministrar == true;
    final visibles = _usuarios
        .where(
          (u) => '${u.nombre} ${u.nombreCompleto} ${u.codigoInterno}'
              .toLowerCase()
              .contains(_busqueda.toLowerCase()),
        )
        .toList();
    return Scaffold(
      bottomNavigationBar: StockGoBottomNavigation(
        store: widget.store,
        current: StockGoModule.equipo,
      ),
      appBar: AppBar(
        leading: StockGoModuleMenu(
          store: widget.store,
          current: StockGoModule.equipo,
        ),
        title: const Text('Vendedores y equipo'),
        actions: [
          if (permitido)
            IconButton(
              onPressed: _auditoria,
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Historial de seguridad',
            ),
          if (permitido)
            IconButton(
              onPressed: _cargar,
              tooltip: 'Actualizar equipo',
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: !permitido
          ? const Center(
              child: Text('Solo el administrador puede consultar el equipo.'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: const LinearGradient(
                                  colors: [
                                    StockGoTheme.navy,
                                    StockGoTheme.teal,
                                  ],
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const StockGoIconBadge(
                                    icon: Icons.groups_2_outlined,
                                    size: 54,
                                    onDark: true,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.store.nombreNegocio,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(color: Colors.white),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    '${_usuarios.where((u) => u.rol == Rol.vendedor).length} vendedores registrados · ${_usuarios.where((u) => u.rol == Rol.administrador).length} administradores',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Estas cuentas pertenecen únicamente a este negocio.',
                                    style: TextStyle(color: Color(0xFFCEE0DE)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: _invitar,
                                  icon: const Icon(Icons.send_outlined),
                                  label: const Text('Invitar vendedor'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _crear,
                                  icon: const Icon(Icons.person_add_alt),
                                  label: const Text('Crear cuenta del equipo'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              onChanged: (v) => setState(() => _busqueda = v),
                              decoration: const InputDecoration(
                                labelText:
                                    'Buscar por usuario, nombre o código',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_error != null)
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(_error!),
                                ),
                              ),
                            if (_error == null && visibles.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No hay cuentas que coincidan con la búsqueda.',
                                ),
                              ),
                            for (final usuario in visibles)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Card(
                                  child: ListTile(
                                    leading: StockGoIconBadge(
                                      icon: usuario.puedeAdministrar
                                          ? Icons.admin_panel_settings_outlined
                                          : Icons.person_outline,
                                    ),
                                    title: Text(usuario.nombreCompleto),
                                    subtitle: Text(
                                      '${usuario.nombre} · ${usuario.codigoInterno}\n${usuario.rol.etiqueta} · ${widget.store.nombreNegocio}',
                                    ),
                                    trailing: IconButton(
                                      tooltip:
                                          usuario.id == widget.store.usuario?.id
                                          ? 'Cambiar mi contraseña'
                                          : 'Restablecer contraseña',
                                      icon: const Icon(
                                        Icons.lock_reset_rounded,
                                      ),
                                      onPressed: () => _restablecer(usuario),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
    );
  }
}
