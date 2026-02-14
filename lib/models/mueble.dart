import 'parte_mueble.dart';

class Mueble {
  final String id;
  String nombre;
  double anchoCm;
  double altoCm;
  double fondoCm;
  String? imagePath;
  bool enProceso;
  int cantidadEnProceso;

  // ✅ AHORA TODO VIVE AQUÍ
  List<ParteMueble> partes;

  // 📓 Fotos de la libreta
  List<String> imagenesMateriales;

  Mueble({
    String? id,
    required this.nombre,
    required this.anchoCm,
    required this.altoCm,
    required this.fondoCm,
    this.imagePath,
    this.enProceso = false,
    this.cantidadEnProceso = 1,
    List<ParteMueble>? partes,
    List<String>? imagenesMateriales,
  }) : id = id ?? _generateId(),
       partes = partes ?? [ParteMueble(nombre: 'General')],
       imagenesMateriales = imagenesMateriales ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'anchoCm': anchoCm,
      'altoCm': altoCm,
      'fondoCm': fondoCm,
      'imagePath': imagePath,
      'enProceso': enProceso,
      'cantidadEnProceso': cantidadEnProceso,
      'imagenesMateriales': imagenesMateriales,
      'partes': partes.map((p) => p.toMap()).toList(),
    };
  }

  factory Mueble.fromMap(Map<String, dynamic> map) {
    return Mueble(
      id: map['id'],
      nombre: map['nombre'],
      anchoCm: (map['anchoCm'] as num).toDouble(),
      altoCm: (map['altoCm'] as num).toDouble(),
      fondoCm: (map['fondoCm'] as num).toDouble(),
      imagePath: map['imagePath'],
      enProceso: map['enProceso'] ?? false,
      cantidadEnProceso: map['cantidadEnProceso'] ?? 1,
      imagenesMateriales: List<String>.from(map['imagenesMateriales'] ?? []),
      partes:
          (map['partes'] as List?)
              ?.map((p) => ParteMueble.fromMap(p))
              .toList() ??
          [ParteMueble(nombre: 'General')],
    );
  }

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
