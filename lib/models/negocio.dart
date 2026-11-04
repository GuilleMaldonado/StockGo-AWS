class Negocio {
  const Negocio({required this.id, required this.nombre, required this.ruta});
  final int id;
  final String nombre;
  final String ruta;
  factory Negocio.fromMap(Map<String, Object?> map) => Negocio(
    id: map['id'] as int,
    nombre: map['nombre'] as String,
    ruta: map['ruta'] as String,
  );
}
