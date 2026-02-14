class MaterialItem {
  final String nombre;
  final String tipo;
  final double espesorMm;
  final double largoCm;
  final double anchoCm;
  final int cantidad;
  final String notas;

  MaterialItem({
    required this.nombre,
    required this.tipo,
    required this.espesorMm,
    required this.largoCm,
    required this.anchoCm,
    required this.cantidad,
    this.notas = '',
  });
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'tipo': tipo,
      'espesorMm': espesorMm,
      'largoCm': largoCm,
      'anchoCm': anchoCm,
      'cantidad': cantidad,
      'notas': notas,
    };
  }

  factory MaterialItem.fromMap(Map<String, dynamic> map) {
    return MaterialItem(
      nombre: map['nombre'],
      tipo: map['tipo'],
      espesorMm: map['espesorMm'],
      largoCm: map['largoCm'],
      anchoCm: map['anchoCm'],
      cantidad: map['cantidad'],
      notas: map['notas'] ?? '',
    );
  }
}
