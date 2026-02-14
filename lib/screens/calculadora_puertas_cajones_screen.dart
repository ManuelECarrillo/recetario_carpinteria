import 'package:flutter/material.dart';
import '../models/material_mueble.dart';
import '../services/storage_service.dart';
import 'cortes_puertas_screen.dart';

enum _TipoFrente { puertaGrande, puertaChica, cajon }

class CalculadoraPuertasCajonesScreen extends StatefulWidget {
  const CalculadoraPuertasCajonesScreen({super.key});

  @override
  State<CalculadoraPuertasCajonesScreen> createState() =>
      _CalculadoraPuertasCajonesScreenState();
}

class _CalculadoraPuertasCajonesScreenState
    extends State<CalculadoraPuertasCajonesScreen> {
  final List<_EntradaHueco> _entradas = [];

  final TextEditingController _sumaPuertasAnchoCtrl = TextEditingController(
    text: '2.8',
  );
  final TextEditingController _sumaPuertasAltoCtrl = TextEditingController(
    text: '2.5',
  );
  final TextEditingController _sumaCajonAnchoCtrl = TextEditingController(
    text: '2.5',
  );
  final TextEditingController _sumaCajonAltoCtrl = TextEditingController(
    text: '2.5',
  );

  String _materialSeleccionado = 'MDF';
  final Set<String> _checklistCompletadas = {};
  bool _estadoCargando = true;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  @override
  void dispose() {
    for (final entrada in _entradas) {
      entrada.dispose();
    }
    _sumaPuertasAnchoCtrl.dispose();
    _sumaPuertasAltoCtrl.dispose();
    _sumaCajonAnchoCtrl.dispose();
    _sumaCajonAltoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    final estado = await StorageService.cargarEstadoPuertasCajones();

    if (!mounted) return;
    setState(() {
      _entradas.clear();
      _checklistCompletadas.clear();

      if (estado != null) {
        _materialSeleccionado = (estado['material'] as String?) ?? 'MDF';
        final sumas = Map<String, dynamic>.from(estado['sumas'] as Map? ?? {});
        _sumaPuertasAnchoCtrl.text = (sumas['puertasAncho'] ?? '2.8')
            .toString();
        _sumaPuertasAltoCtrl.text = (sumas['puertasAlto'] ?? '2.5').toString();
        _sumaCajonAnchoCtrl.text = (sumas['cajonAncho'] ?? '2.5').toString();
        _sumaCajonAltoCtrl.text = (sumas['cajonAlto'] ?? '2.5').toString();

        final rawEntradas = (estado['entradas'] as List?) ?? [];
        for (final raw in rawEntradas) {
          if (raw is Map) {
            _entradas.add(
              _EntradaHueco.fromMap(Map<String, dynamic>.from(raw)),
            );
          }
        }

        final rawChecklist = (estado['checklist'] as List?) ?? [];
        for (final key in rawChecklist) {
          _checklistCompletadas.add(key.toString());
        }
      }

      if (_entradas.isEmpty) {
        _entradas.add(_EntradaHueco());
      }

      _limpiarChecklistInvalido();
      _estadoCargando = false;
    });
  }

  Future<void> _guardarEstado() async {
    final estado = <String, dynamic>{
      'material': _materialSeleccionado,
      'sumas': {
        'puertasAncho': _sumaPuertasAnchoCtrl.text.trim(),
        'puertasAlto': _sumaPuertasAltoCtrl.text.trim(),
        'cajonAncho': _sumaCajonAnchoCtrl.text.trim(),
        'cajonAlto': _sumaCajonAltoCtrl.text.trim(),
      },
      'entradas': _entradas.map((e) => e.toMap()).toList(),
      'checklist': _checklistCompletadas.toList(),
    };
    await StorageService.guardarEstadoPuertasCajones(estado);
  }

  Future<void> _resetearTodo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetear calculadora'),
        content: const Text(
          'Se borraran formulas, huecos y checklist de este apartado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    for (final entrada in _entradas) {
      entrada.dispose();
    }

    setState(() {
      _entradas.clear();
      _entradas.add(_EntradaHueco());
      _materialSeleccionado = 'MDF';
      _sumaPuertasAnchoCtrl.text = '2.8';
      _sumaPuertasAltoCtrl.text = '2.5';
      _sumaCajonAnchoCtrl.text = '2.5';
      _sumaCajonAltoCtrl.text = '2.5';
      _checklistCompletadas.clear();
    });

    await StorageService.borrarEstadoPuertasCajones();
    await _guardarEstado();
  }

  void _agregarEntrada() {
    setState(() {
      _entradas.add(_EntradaHueco());
      _limpiarChecklistInvalido();
    });
    _guardarEstado();
  }

  void _eliminarEntrada(int index) {
    if (_entradas.length == 1) return;
    setState(() {
      final entrada = _entradas.removeAt(index);
      entrada.dispose();
      _limpiarChecklistInvalido();
    });
    _guardarEstado();
  }

  void _onParametrosChanged() {
    setState(() {
      _limpiarChecklistInvalido();
    });
    _guardarEstado();
  }

  int _parseCantidad(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 1) return 0;
    return parsed;
  }

  double _parseDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double _sumaPuertasAncho() => _parseDouble(_sumaPuertasAnchoCtrl.text);
  double _sumaPuertasAlto() => _parseDouble(_sumaPuertasAltoCtrl.text);
  double _sumaCajonAncho() => _parseDouble(_sumaCajonAnchoCtrl.text);
  double _sumaCajonAlto() => _parseDouble(_sumaCajonAltoCtrl.text);

  List<_PiezaCalculada> _calcularPiezas() {
    final piezas = <_PiezaCalculada>[];

    final sumaPuertaAncho = _sumaPuertasAncho();
    final sumaPuertaAlto = _sumaPuertasAlto();
    final sumaCajonAncho = _sumaCajonAncho();
    final sumaCajonAlto = _sumaCajonAlto();

    for (final entrada in _entradas) {
      final anchoHueco = _parseDouble(entrada.anchoHuecoCtrl.text);
      final altoHueco = _parseDouble(entrada.altoHuecoCtrl.text);
      final cantidadHuecos = _parseCantidad(entrada.cantidadCtrl.text);

      if (anchoHueco <= 0 || altoHueco <= 0 || cantidadHuecos <= 0) continue;

      switch (entrada.tipo) {
        case _TipoFrente.puertaGrande:
          final ancho = (anchoHueco + sumaPuertaAncho) / 2;
          final alto = altoHueco + sumaPuertaAlto;
          if (ancho <= 0 || alto <= 0) break;
          piezas.add(
            _PiezaCalculada(
              tipoEtiqueta: 'Puertas grandes',
              tipoMaterial: 'Puertas grandes',
              largoCm: alto,
              anchoCm: ancho,
              cantidad: cantidadHuecos,
              material: _materialSeleccionado,
            ),
          );
          break;
        case _TipoFrente.puertaChica:
          final ancho = (anchoHueco + sumaPuertaAncho) / 2;
          final alto = altoHueco + sumaPuertaAlto;
          if (ancho <= 0 || alto <= 0) break;
          piezas.add(
            _PiezaCalculada(
              tipoEtiqueta: 'Puertas chicas',
              tipoMaterial: 'Puertas chicas',
              largoCm: alto,
              anchoCm: ancho,
              cantidad: cantidadHuecos,
              material: _materialSeleccionado,
            ),
          );
          break;
        case _TipoFrente.cajon:
          final ancho = anchoHueco + sumaCajonAncho;
          final alto = altoHueco + sumaCajonAlto;
          if (ancho <= 0 || alto <= 0) break;
          piezas.add(
            _PiezaCalculada(
              tipoEtiqueta: 'Cajones',
              tipoMaterial: 'Tapaderas de Cajones',
              largoCm: alto,
              anchoCm: ancho,
              cantidad: cantidadHuecos,
              material: _materialSeleccionado,
            ),
          );
          break;
      }
    }

    final Map<String, _PiezaCalculada> agrupadas = {};
    for (final pieza in piezas) {
      final existente = agrupadas[pieza.key];
      if (existente == null) {
        agrupadas[pieza.key] = pieza;
      } else {
        existente.cantidad += pieza.cantidad;
      }
    }

    final resultado = agrupadas.values.toList();
    resultado.sort((a, b) {
      final tipo = a.tipoEtiqueta.compareTo(b.tipoEtiqueta);
      if (tipo != 0) return tipo;
      final largo = a.largoCm.compareTo(b.largoCm);
      if (largo != 0) return largo;
      return a.anchoCm.compareTo(b.anchoCm);
    });
    return resultado;
  }

  void _limpiarChecklistInvalido() {
    final validos = _calcularPiezas().map((p) => p.key).toSet();
    _checklistCompletadas.removeWhere((k) => !validos.contains(k));
  }

  void _toggleChecklist(String key, bool value) {
    setState(() {
      if (value) {
        _checklistCompletadas.add(key);
      } else {
        _checklistCompletadas.remove(key);
      }
    });
    _guardarEstado();
  }

  void _verCortes() {
    final piezas = _calcularPiezas();
    if (piezas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un hueco valido para calcular.'),
        ),
      );
      return;
    }

    final materiales = piezas
        .map(
          (p) => MaterialMueble(
            tipo: p.tipoMaterial,
            material: p.material,
            espesorMm: 15.0,
            largoCm: p.largoCm,
            anchoCm: p.anchoCm,
            cantidad: p.cantidad,
          ),
        )
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CortesHojasScreen(
          materiales: materiales,
          titulo: 'Cortes puertas y cajones',
        ),
      ),
    );
  }

  String _labelTipo(_TipoFrente tipo) {
    switch (tipo) {
      case _TipoFrente.puertaGrande:
        return 'Puertas grandes';
      case _TipoFrente.puertaChica:
        return 'Puertas chicas';
      case _TipoFrente.cajon:
        return 'Cajones';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_estadoCargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final piezas = _calcularPiezas();
    final totalPiezas = piezas.fold<int>(0, (sum, p) => sum + p.cantidad);
    final piezasCompletadas = piezas.fold<int>(
      0,
      (sum, p) =>
          sum + (_checklistCompletadas.contains(p.key) ? p.cantidad : 0),
    );
    final progreso = totalPiezas == 0 ? 0.0 : piezasCompletadas / totalPiezas;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        title: const Text('Puertas y cajones'),
        actions: [
          IconButton(
            tooltip: 'Resetear',
            onPressed: _resetearTodo,
            icon: const Icon(Icons.restart_alt, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: _agregarEntrada,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              title: const Text(
                'Ajuste de formulas (solo sumas al hueco)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Puertas: sumar al ancho (antes de /2)'),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _sumaPuertasAnchoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '+ cm',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _onParametrosChanged(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Puertas: sumar al alto')),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _sumaPuertasAltoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '+ cm',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _onParametrosChanged(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Cajones: sumar al ancho')),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _sumaCajonAnchoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '+ cm',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _onParametrosChanged(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Cajones: sumar al alto')),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _sumaCajonAltoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '+ cm',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _onParametrosChanged(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DropdownButtonFormField<String>(
                initialValue: _materialSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Material (15 mm)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'MDF', child: Text('MDF')),
                  DropdownMenuItem(value: 'Okume', child: Text('Okume')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _materialSeleccionado = value;
                    _limpiarChecklistInvalido();
                  });
                  _guardarEstado();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._entradas.asMap().entries.map((entry) {
            final index = entry.key;
            final fila = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hueco ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _eliminarEntrada(index),
                        ),
                      ],
                    ),
                    DropdownButtonFormField<_TipoFrente>(
                      initialValue: fila.tipo,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de frente',
                        border: OutlineInputBorder(),
                      ),
                      items: _TipoFrente.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(_labelTipo(t)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          fila.tipo = value;
                          _limpiarChecklistInvalido();
                        });
                        _guardarEstado();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fila.anchoHuecoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Ancho hueco (cm)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _onParametrosChanged(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: fila.altoHuecoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Alto hueco (cm)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _onParametrosChanged(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 95,
                          child: TextField(
                            controller: fila.cantidadCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _onParametrosChanged(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Progreso de piezas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${(progreso * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progreso,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade300,
                    color: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 6),
                  Text('$piezasCompletadas de $totalPiezas piezas completadas'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: const Text(
                'Lista final de piezas (checklist)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: [
                if (piezas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Aun no hay piezas calculadas.'),
                  )
                else
                  ...piezas.map((p) {
                    final checked = _checklistCompletadas.contains(p.key);
                    final style = TextStyle(
                      color: checked ? Colors.grey.shade600 : Colors.black87,
                      decoration: checked ? TextDecoration.lineThrough : null,
                    );
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (value) =>
                          _toggleChecklist(p.key, value ?? false),
                      dense: true,
                      title: RichText(
                        text: TextSpan(
                          style: style,
                          children: [
                            TextSpan(
                              text: '${p.cantidad} x ${p.tipoEtiqueta} - ',
                            ),
                            TextSpan(
                              text:
                                  '${_fmt(p.largoCm)} x ${_fmt(p.anchoCm)} cm',
                              style: style.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: ' (${p.material} 15 mm)'),
                          ],
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3A2F),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _verCortes,
            icon: const Icon(Icons.grid_view),
            label: const Text('Ver cortes'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _EntradaHueco {
  _TipoFrente tipo;
  final TextEditingController anchoHuecoCtrl;
  final TextEditingController altoHuecoCtrl;
  final TextEditingController cantidadCtrl;

  _EntradaHueco({
    this.tipo = _TipoFrente.puertaGrande,
    String anchoHueco = '',
    String altoHueco = '',
    String cantidad = '1',
  }) : anchoHuecoCtrl = TextEditingController(text: anchoHueco),
       altoHuecoCtrl = TextEditingController(text: altoHueco),
       cantidadCtrl = TextEditingController(text: cantidad);

  factory _EntradaHueco.fromMap(Map<String, dynamic> map) {
    return _EntradaHueco(
      tipo: _tipoFromString(map['tipo']?.toString()),
      anchoHueco: map['anchoHueco']?.toString() ?? '',
      altoHueco: map['altoHueco']?.toString() ?? '',
      cantidad: map['cantidad']?.toString() ?? '1',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo.name,
      'anchoHueco': anchoHuecoCtrl.text.trim(),
      'altoHueco': altoHuecoCtrl.text.trim(),
      'cantidad': cantidadCtrl.text.trim(),
    };
  }

  void dispose() {
    anchoHuecoCtrl.dispose();
    altoHuecoCtrl.dispose();
    cantidadCtrl.dispose();
  }
}

class _PiezaCalculada {
  final String tipoEtiqueta;
  final String tipoMaterial;
  final double largoCm;
  final double anchoCm;
  int cantidad;
  final String material;

  _PiezaCalculada({
    required this.tipoEtiqueta,
    required this.tipoMaterial,
    required this.largoCm,
    required this.anchoCm,
    required this.cantidad,
    required this.material,
  });

  String get key =>
      '$tipoMaterial|$material|${largoCm.toStringAsFixed(2)}|${anchoCm.toStringAsFixed(2)}';
}

_TipoFrente _tipoFromString(String? raw) {
  for (final tipo in _TipoFrente.values) {
    if (tipo.name == raw) return tipo;
  }
  return _TipoFrente.puertaGrande;
}

String _fmt(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}
