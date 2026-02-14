import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  String _display = '0';
  double? _valor;
  String? _operador;
  bool _limpiarPantalla = false;
  String? _ultimaExpresion;
  final List<_HistorialItem> _historial = [];

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    final data = await StorageService.cargarHistorialCalculadora();
    if (!mounted) return;
    setState(() {
      _historial
        ..clear()
        ..addAll(
          data
              .where(
                (e) => (e['expresion'] ?? '').isNotEmpty,
              )
              .map(
                (e) => _HistorialItem(
                  expresion: e['expresion'] ?? '',
                  resultado: e['resultado'] ?? '',
                ),
              ),
        );
    });
  }

  Future<void> _guardarHistorial() async {
    final data = _historial
        .map(
          (e) => {
            'expresion': e.expresion,
            'resultado': e.resultado,
          },
        )
        .toList();
    await StorageService.guardarHistorialCalculadora(data);
  }

  void _presionar(String tecla) {
    setState(() {
      if (tecla == 'C') {
        _display = '0';
        _valor = null;
        _operador = null;
        _limpiarPantalla = false;
        _ultimaExpresion = null;
        return;
      }
      if (tecla == '⌫') {
        if (_limpiarPantalla) {
          _display = '0';
          _limpiarPantalla = false;
          return;
        }
        if (_display.length <= 1) {
          _display = '0';
        } else {
          _display = _display.substring(0, _display.length - 1);
        }
        return;
      }

      if (_esOperador(tecla)) {
        final actual = _parse(_display);
        if (_valor == null) {
          _valor = actual;
        } else if (!_limpiarPantalla) {
          _valor = _calcular(_valor!, actual, _operador);
          _display = _format(_valor!);
        }
        _operador = tecla;
        _limpiarPantalla = true;
        _ultimaExpresion = null;
        return;
      }

      if (tecla == '=') {
        if (_valor == null || _operador == null) return;
        final actual = _parse(_display);
        final expresion = '${_format(_valor!)} $_operador ${_format(actual)}';
        final resultado = _calcular(_valor!, actual, _operador);
        _display = _format(resultado);
        _ultimaExpresion = '$expresion =';
        _historial.insert(
          0,
          _HistorialItem(expresion: expresion, resultado: _display),
        );
        _guardarHistorial();
        _valor = null;
        _operador = null;
        _limpiarPantalla = true;
        return;
      }

      if (_limpiarPantalla) {
        _display = '0';
        _limpiarPantalla = false;
      }

      if (tecla == '.') {
        if (_display.contains('.')) return;
        _display = '$_display.';
        return;
      }

      if (_display == '0') {
        _display = tecla;
      } else {
        _display = '$_display$tecla';
      }
    });
  }

  bool _esOperador(String tecla) {
    return tecla == '+' || tecla == '-' || tecla == '×' || tecla == '÷';
  }

  double _parse(String valor) => double.tryParse(valor) ?? 0;

  double _calcular(double a, double b, String? op) {
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        return b == 0 ? 0 : a / b;
      default:
        return b;
    }
  }

  String _format(double valor) {
    final fixed = valor.toStringAsFixed(6);
    return fixed.replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        title: const Text('Calculadora'),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHistorial(),
            _buildPantalla(),
            const Divider(height: 1),
            Expanded(
              flex: 4,
              child: GridView.count(
                crossAxisCount: 4,
                childAspectRatio: 1.3,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                mainAxisSpacing: 6,
                crossAxisSpacing: 8,
                children: _buildButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildButtons() {
    final botones = [
      'C',
      '⌫',
      '÷',
      '×',
      '7',
      '8',
      '9',
      '-',
      '4',
      '5',
      '6',
      '+',
      '1',
      '2',
      '3',
      '=',
      '0',
      '.',
    ];

    return botones.map(_boton).toList();
  }

  Widget _buildHistorial() {
    return Expanded(
      flex: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Historial',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (_historial.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _historial.clear());
                      _guardarHistorial();
                    },
                    child: const Text('Borrar todo'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _historial.isEmpty
                ? Center(
                    child: Text(
                      'Sin operaciones',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _historial.length,
                    itemBuilder: (context, index) {
                      final item = _historial[index];
                      return ListTile(
                        dense: true,
                        title: Text(item.expresion),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.resultado,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() {
                                  _historial.removeAt(index);
                                });
                                _guardarHistorial();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPantalla() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _expresionActual(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Text(
            _display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _expresionActual() {
    if (_operador == null) {
      return _ultimaExpresion ?? '';
    }
    if (_valor == null) return '';
    if (_limpiarPantalla) {
      return '${_format(_valor!)} $_operador';
    }
    return '${_format(_valor!)} $_operador $_display';
  }

  Widget _boton(String texto) {
    final esOperador = _esOperador(texto) || texto == '=';
    final esAccion = texto == 'C' || texto == '⌫';

    Color fondo;
    Color textoColor = Colors.black87;

    if (esOperador) {
      fondo = const Color(0xFF1B3A2F);
      textoColor = Colors.white;
    } else if (esAccion) {
      fondo = Colors.grey.shade300;
    } else {
      fondo = Colors.white;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: fondo,
        foregroundColor: textoColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () => _presionar(texto),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _HistorialItem {
  final String expresion;
  final String resultado;

  _HistorialItem({required this.expresion, required this.resultado});
}
