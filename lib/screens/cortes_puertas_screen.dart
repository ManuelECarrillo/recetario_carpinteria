import 'package:flutter/material.dart';
import '../models/material_mueble.dart';

class CortesHojasScreen extends StatefulWidget {
  final List<MaterialMueble> materiales;
  final String titulo;

  const CortesHojasScreen({
    super.key,
    required this.materiales,
    required this.titulo,
  });

  @override
  State<CortesHojasScreen> createState() => _CortesHojasScreenState();
}

class _CortesHojasScreenState extends State<CortesHojasScreen> {
  static const double _hojaAnchoCm = 244;
  static const double _hojaAltoCm = 122;
  bool _permitirGiro = false;

  @override
  Widget build(BuildContext context) {
    final piezas = _expandirPiezas(widget.materiales);
    final resultado = _generarCortes(piezas, _permitirGiro);
    final coloresPorTipo = _coloresPorTipo(piezas);
    final etiquetasPorTipo = _etiquetasPorTipo(piezas);

    final totalHojas = resultado.hojas.length;
    final areaTotalPiezas = resultado.areaTotal;
    final areaTotalHojas = totalHojas == 0
        ? 0
        : totalHojas * _hojaAnchoCm * _hojaAltoCm;
    final usoGeneral = areaTotalHojas == 0
        ? 0
        : (areaTotalPiezas / areaTotalHojas) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        title: Text(widget.titulo),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de cortes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('Piezas: ${piezas.length}'),
                  Text('Hojas: $totalHojas'),
                  Text('Uso general: ${usoGeneral.toStringAsFixed(0)}%'),
                  if (etiquetasPorTipo.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Color por tipo de pieza',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: etiquetasPorTipo.entries.map((entry) {
                        final color =
                            coloresPorTipo[entry.key] ?? Colors.blueGrey;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: color.withOpacity(0.16),
                            border: Border.all(color: color.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(entry.value),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: Text('Permitir girar piezas')),
                      Switch(
                        value: _permitirGiro,
                        onChanged: (value) {
                          setState(() => _permitirGiro = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (resultado.fuera.isNotEmpty)
            Card(
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Piezas fuera de hoja',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...resultado.fuera.map(
                      (p) => Text('- ${_fmt(p.ancho)} x ${_fmt(p.alto)} cm'),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (resultado.hojas.isEmpty)
            Text(
              'No hay piezas para mostrar.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...resultado.hojas.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final hoja = entry.value;
              return _cardHoja(context, index, hoja, coloresPorTipo);
            }),
        ],
      ),
    );
  }

  Widget _cardHoja(
    BuildContext context,
    int index,
    _Hoja hoja,
    Map<String, Color> coloresPorTipo,
  ) {
    final areaHoja = _hojaAnchoCm * _hojaAltoCm;
    final uso = areaHoja == 0 ? 0 : (hoja.areaUsada / areaHoja) * 100;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 260 + (index * 50)),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Hoja $index',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${uso.toStringAsFixed(0)}% uso',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: _hojaAnchoCm / _hojaAltoCm,
                child: CustomPaint(
                  painter: _HojaPainter(hoja, coloresPorTipo),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaPainter extends CustomPainter {
  final _Hoja hoja;
  final Map<String, Color> coloresPorTipo;

  _HojaPainter(this.hoja, this.coloresPorTipo);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _CortesHojasScreenState._hojaAnchoCm;
    final scaleY = size.height / _CortesHojasScreenState._hojaAltoCm;
    for (var i = 0; i < hoja.piezas.length; i++) {
      final p = hoja.piezas[i];
      final rect = Rect.fromLTWH(
        p.x * scaleX,
        p.y * scaleY,
        p.ancho * scaleX,
        p.alto * scaleY,
      );

      final fill = Paint()
        ..color = _colorParaTipo(p.tipo, coloresPorTipo).withOpacity(0.5)
        ..style = PaintingStyle.fill;
      final border = Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, border);

      if (rect.width > 40 && rect.height > 16) {
        final text = '${_fmt(p.ancho)}x${_fmt(p.alto)}';
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: rect.width - 4);
        tp.paint(canvas, Offset(rect.left + 2, rect.top + 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Hoja {
  final List<_PiezaUbicada> piezas = [];
  double areaUsada = 0;
  double altoUsado = 0;
  final List<_Fila> filas = [];
}

class _Fila {
  final double y;
  double alto;
  double x;

  _Fila({required this.y, required this.alto, required this.x});
}

class _Pieza {
  final double ancho;
  final double alto;
  final String tipo;

  _Pieza({required this.ancho, required this.alto, required this.tipo});

  double get area => ancho * alto;
}

class _PiezaUbicada {
  final double x;
  final double y;
  final double ancho;
  final double alto;
  final String tipo;

  _PiezaUbicada({
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
    required this.tipo,
  });
}

class _ResultadoCortes {
  final List<_Hoja> hojas;
  final List<_Pieza> fuera;
  final double areaTotal;

  _ResultadoCortes({
    required this.hojas,
    required this.fuera,
    required this.areaTotal,
  });
}

_ResultadoCortes _generarCortes(List<_Pieza> piezas, bool permitirGiro) {
  final ordenadas = [...piezas];
  ordenadas.sort((a, b) => b.alto.compareTo(a.alto));

  final List<_Hoja> hojas = [];
  final List<_Pieza> fuera = [];
  double areaTotal = 0;

  for (final pieza in ordenadas) {
    areaTotal += pieza.area;
    if (!_puedeEntrarEnHoja(pieza, permitirGiro)) {
      fuera.add(pieza);
      continue;
    }

    var colocada = false;
    for (final hoja in hojas) {
      if (_intentarColocarEnHoja(hoja, pieza, permitirGiro)) {
        colocada = true;
        break;
      }
    }
    if (!colocada) {
      final hoja = _Hoja();
      _intentarColocarEnHoja(hoja, pieza, permitirGiro);
      hojas.add(hoja);
    }
  }

  return _ResultadoCortes(hojas: hojas, fuera: fuera, areaTotal: areaTotal);
}

bool _intentarColocarEnHoja(_Hoja hoja, _Pieza pieza, bool permitirGiro) {
  const double hojaAncho = _CortesHojasScreenState._hojaAnchoCm;
  const double hojaAlto = _CortesHojasScreenState._hojaAltoCm;

  final orientaciones = _orientaciones(pieza, permitirGiro);

  for (final fila in hoja.filas) {
    final mejor = _mejorOrientacionEnFila(fila, orientaciones, hojaAncho);
    if (mejor != null) {
      hoja.piezas.add(
        _PiezaUbicada(
          x: fila.x,
          y: fila.y,
          ancho: mejor.ancho,
          alto: mejor.alto,
          tipo: mejor.tipo,
        ),
      );
      fila.x += mejor.ancho;
      hoja.areaUsada += mejor.ancho * mejor.alto;
      return true;
    }
  }

  final altoDisponible = hojaAlto - hoja.altoUsado;
  final orientacionNueva = _mejorOrientacionNuevaFila(
    orientaciones,
    hojaAncho,
    altoDisponible,
  );
  if (orientacionNueva != null) {
    final fila = _Fila(y: hoja.altoUsado, alto: orientacionNueva.alto, x: 0);
    hoja.filas.add(fila);
    hoja.altoUsado += orientacionNueva.alto;

    hoja.piezas.add(
      _PiezaUbicada(
        x: fila.x,
        y: fila.y,
        ancho: orientacionNueva.ancho,
        alto: orientacionNueva.alto,
        tipo: orientacionNueva.tipo,
      ),
    );
    fila.x += orientacionNueva.ancho;
    hoja.areaUsada += orientacionNueva.ancho * orientacionNueva.alto;
    return true;
  }

  return false;
}

_Pieza? _mejorOrientacionEnFila(
  _Fila fila,
  List<_Pieza> orientaciones,
  double hojaAncho,
) {
  final anchoDisponible = hojaAncho - fila.x;
  final opciones = orientaciones
      .where((o) => o.alto <= fila.alto && o.ancho <= anchoDisponible)
      .toList();
  if (opciones.isEmpty) return null;
  opciones.sort((a, b) {
    final desperdicioA = anchoDisponible - a.ancho;
    final desperdicioB = anchoDisponible - b.ancho;
    final porDesperdicio = desperdicioA.compareTo(desperdicioB);
    if (porDesperdicio != 0) return porDesperdicio;
    return a.alto.compareTo(b.alto);
  });
  return opciones.first;
}

_Pieza? _mejorOrientacionNuevaFila(
  List<_Pieza> orientaciones,
  double hojaAncho,
  double altoDisponible,
) {
  final opciones = orientaciones
      .where((o) => o.ancho <= hojaAncho && o.alto <= altoDisponible)
      .toList();
  if (opciones.isEmpty) return null;
  opciones.sort((a, b) {
    final porAlto = a.alto.compareTo(b.alto);
    if (porAlto != 0) return porAlto;
    return b.ancho.compareTo(a.ancho);
  });
  return opciones.first;
}

List<_Pieza> _orientaciones(_Pieza pieza, bool permitirGiro) {
  if (!permitirGiro || pieza.ancho == pieza.alto) {
    return [pieza];
  }
  return [
    pieza,
    _Pieza(ancho: pieza.alto, alto: pieza.ancho, tipo: pieza.tipo),
  ];
}

bool _puedeEntrarEnHoja(_Pieza pieza, bool permitirGiro) {
  const double hojaAncho = _CortesHojasScreenState._hojaAnchoCm;
  const double hojaAlto = _CortesHojasScreenState._hojaAltoCm;
  final cabeNormal = pieza.ancho <= hojaAncho && pieza.alto <= hojaAlto;
  if (!permitirGiro) return cabeNormal;
  final cabeGiro = pieza.alto <= hojaAncho && pieza.ancho <= hojaAlto;
  return cabeNormal || cabeGiro;
}

List<_Pieza> _expandirPiezas(List<MaterialMueble> materiales) {
  final piezas = <_Pieza>[];
  for (final material in materiales) {
    if (material.largoCm <= 0 || material.anchoCm <= 0) continue;
    for (var i = 0; i < material.cantidad; i++) {
      piezas.add(
        _Pieza(
          ancho: material.largoCm,
          alto: material.anchoCm,
          tipo: material.tipo,
        ),
      );
    }
  }
  return piezas;
}

Map<String, Color> _coloresPorTipo(List<_Pieza> piezas) {
  final colores = <String, Color>{};
  var fallbackIndex = 0;
  for (final pieza in piezas) {
    final tipo = _normalizarTipo(pieza.tipo);
    if (colores.containsKey(tipo)) continue;
    final colorBase = _coloresBasePorTipo[tipo];
    if (colorBase != null) {
      colores[tipo] = colorBase;
      continue;
    }
    colores[tipo] = _colorPalette()[fallbackIndex % _colorPalette().length];
    fallbackIndex++;
  }
  return colores;
}

Map<String, String> _etiquetasPorTipo(List<_Pieza> piezas) {
  final etiquetas = <String, String>{};
  for (final pieza in piezas) {
    final tipo = _normalizarTipo(pieza.tipo);
    etiquetas.putIfAbsent(tipo, () => pieza.tipo.trim());
  }
  return etiquetas;
}

Color _colorParaTipo(String tipo, Map<String, Color> coloresPorTipo) {
  return coloresPorTipo[_normalizarTipo(tipo)] ?? const Color(0xFF90A4AE);
}

String _normalizarTipo(String tipo) {
  return tipo
      .trim()
      .toLowerCase()
      .replaceAll('\u00F1', 'n')
      .replaceAll('\u00E1', 'a')
      .replaceAll('\u00E9', 'e')
      .replaceAll('\u00ED', 'i')
      .replaceAll('\u00F3', 'o')
      .replaceAll('\u00FA', 'u');
}

const Map<String, Color> _coloresBasePorTipo = {
  'puertas chicas': Color(0xFF42A5F5),
  'puertas grandes': Color(0xFFEF5350),
  'tapaderas de cajones': Color(0xFFFFA726),
  'cajones': Color(0xFF26A69A),
  'entrepanos': Color(0xFFAB47BC),
  'paredes del mueble': Color(0xFF7E57C2),
  'tapas traseras': Color(0xFF8D6E63),
  'tiras de madera': Color(0xFF66BB6A),
};

List<Color> _colorPalette() {
  return [
    const Color(0xFF81C784),
    const Color(0xFF64B5F6),
    const Color(0xFFFFB74D),
    const Color(0xFFBA68C8),
    const Color(0xFFE57373),
    const Color(0xFF4DB6AC),
  ];
}

String _fmt(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}
