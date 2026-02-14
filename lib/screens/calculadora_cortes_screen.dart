import 'package:flutter/material.dart';
import '../models/material_mueble.dart';
import 'cortes_puertas_screen.dart';

class CalculadoraCortesScreen extends StatefulWidget {
  const CalculadoraCortesScreen({super.key});

  @override
  State<CalculadoraCortesScreen> createState() =>
      _CalculadoraCortesScreenState();
}

class _CalculadoraCortesScreenState extends State<CalculadoraCortesScreen> {
  final List<_EntradaCorte> _entradas = [_EntradaCorte()];

  @override
  void dispose() {
    for (final entrada in _entradas) {
      entrada.dispose();
    }
    super.dispose();
  }

  void _agregarEntrada() {
    setState(() {
      _entradas.add(_EntradaCorte());
    });
  }

  void _eliminarEntrada(int index) {
    if (_entradas.length == 1) return;
    setState(() {
      final entrada = _entradas.removeAt(index);
      entrada.dispose();
    });
  }

  int _parseCantidad(String value) {
    final num? parsed = num.tryParse(value.trim());
    if (parsed == null) return 0;
    return parsed.toInt();
  }

  void _abrirPlanoCortes() {
    final Map<String, MaterialMueble> agrupados = {};

    for (final entrada in _entradas) {
      final largo = double.tryParse(entrada.largoCtrl.text.trim()) ?? 0;
      final ancho = double.tryParse(entrada.anchoCtrl.text.trim()) ?? 0;
      final cantidad = _parseCantidad(entrada.cantidadCtrl.text);

      if (largo <= 0 || ancho <= 0 || cantidad <= 0) {
        continue;
      }

      final key = '${largo.toStringAsFixed(2)}|${ancho.toStringAsFixed(2)}';
      final existente = agrupados[key];

      if (existente == null) {
        agrupados[key] = MaterialMueble(
          tipo: '${_fmt(largo)} x ${_fmt(ancho)}',
          largoCm: largo,
          anchoCm: ancho,
          cantidad: cantidad,
        );
      } else {
        existente.cantidad += cantidad;
      }
    }

    final materiales = agrupados.values.toList();
    if (materiales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agrega al menos una medida valida con cantidad mayor a 0',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CortesHojasScreen(
          materiales: materiales,
          titulo: 'Calculadora de cortes',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Calculadora de cortes'),
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
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Hoja base: 244 x 122 cm\n'
                'Agrega medidas y cantidad para simular el mejor corte.',
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
                          'Pieza ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _eliminarEntrada(index),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: fila.largoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Largo (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: fila.anchoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Ancho (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: fila.cantidadCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              border: OutlineInputBorder(),
                            ),
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
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3A2F),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _abrirPlanoCortes,
            icon: const Icon(Icons.grid_view),
            label: const Text('Calcular cortes'),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _EntradaCorte {
  final TextEditingController largoCtrl = TextEditingController();
  final TextEditingController anchoCtrl = TextEditingController();
  final TextEditingController cantidadCtrl = TextEditingController(text: '1');

  void dispose() {
    largoCtrl.dispose();
    anchoCtrl.dispose();
    cantidadCtrl.dispose();
  }
}

String _fmt(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}
