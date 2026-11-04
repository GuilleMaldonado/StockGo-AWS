enum Rol {
  administrador('Administrador'),
  vendedor('Vendedor'),
  invitado('Invitado');

  const Rol(this.etiqueta);
  final String etiqueta;
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.rol,
    this.nombres = '',
    this.apellidos = '',
    this.codigoInterno = '',
    this.requiereCambioPassword = false,
    this.versionCredencial = 0,
  });

  final int id;
  final String nombre;
  final Rol rol;
  final String nombres;
  final String apellidos;
  final String codigoInterno;
  final bool requiereCambioPassword;
  final int versionCredencial;
  String get nombreCompleto => '$nombres $apellidos'.trim().isEmpty
      ? nombre
      : '$nombres $apellidos'.trim();
  bool get perfilCompleto => nombres.isNotEmpty && apellidos.isNotEmpty;
  static String? validarNombre(String? valor) =>
      RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?:[ '’-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$")
              .hasMatch((valor ?? '').trim()) &&
          (valor ?? '').trim().length <= 80
      ? null
      : 'Usa letras y espacios, sin números (máximo 80 caracteres).';

  bool get puedeAdministrar => rol == Rol.administrador;
  bool get puedeVender => rol == Rol.administrador || rol == Rol.vendedor;

  factory Usuario.fromMap(Map<String, Object?> map) => Usuario(
    id: map['id'] as int,
    nombre: map['nombre'] as String,
    rol: Rol.values.byName(map['rol'] as String),
    nombres: map['nombres'] as String? ?? '',
    apellidos: map['apellidos'] as String? ?? '',
    codigoInterno: map['codigoInterno'] as String? ?? '',
    requiereCambioPassword:
        map['requiereCambioPassword'] == 1 ||
        map['requiereCambioPassword'] == true,
    versionCredencial: map['versionCredencial'] as int? ?? 0,
  );
}
