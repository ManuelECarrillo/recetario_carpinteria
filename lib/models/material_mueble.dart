class MaterialMueble {
  String tipo; // Ej: Puertas, Entrepaños, Tiras de madera
  String? material; // MDF, Okume, etc (null para tiras)
  double? espesorMm;
  double largoCm;
  double anchoCm;
  int cantidad;
  bool completado; // 👈 NUEVO

  MaterialMueble({
    required this.tipo,
    this.material,
    this.espesorMm,
    required this.largoCm,
    required this.anchoCm,
    required this.cantidad,
    this.completado = false, // 👈 default
  });

  /// 🔁 CONVERTIR A MAP (para guardar)
  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'material': material,
      'espesorMm': espesorMm,
      'largoCm': largoCm,
      'anchoCm': anchoCm,
      'cantidad': cantidad,
      'completado': completado,
    };
  }

  /// 🔁 CREAR DESDE MAP (cuando carguemos)
  factory MaterialMueble.fromMap(Map<String, dynamic> map) {
    return MaterialMueble(
      tipo: map['tipo'],
      material: map['material'],
      espesorMm: map['espesorMm'] != null
          ? (map['espesorMm'] as num).toDouble()
          : null,
      largoCm: (map['largoCm'] as num).toDouble(),
      anchoCm: (map['anchoCm'] as num).toDouble(),
      cantidad: map['cantidad'],
      completado: map['completado'] ?? false,
    );
  }
}
