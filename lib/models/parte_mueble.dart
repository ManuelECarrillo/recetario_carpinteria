class ParteMueble {
  String nombre;
  List<Map<String, dynamic>> materiales;

  ParteMueble({required this.nombre, List<Map<String, dynamic>>? materiales})
    : materiales = materiales ?? [];

  Map<String, dynamic> toMap() {
    return {'nombre': nombre, 'materiales': materiales};
  }

  factory ParteMueble.fromMap(Map<String, dynamic> map) {
    return ParteMueble(
      nombre: map['nombre'],
      materiales: List<Map<String, dynamic>>.from(map['materiales'] ?? []),
    );
  }
}
