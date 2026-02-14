import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  Map<String, int> _inventario = {};
  Map<String, Map<String, int>> _historial = {};
  Map<String, Map<String, int>> _historialMuebles = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final inventario = await StorageService.cargarInventarioHojas();
    final historial = await StorageService.cargarHistorialSemanal();
    final historialMuebles = await StorageService.cargarHistorialMuebles();
    if (!mounted) return;
    setState(() {
      _inventario = inventario;
      _historial = historial;
      _historialMuebles = historialMuebles;
      _cargando = false;
    });
  }

  Future<void> _agregarHojas() async {
    String? materialSeleccionado;
    final cantidadCtrl = TextEditingController();
    final otroCtrl = TextEditingController();

    final opciones = _materialesDisponibles();

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Agregar hojas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: materialSeleccionado,
                  hint: const Text('Selecciona material'),
                  items: opciones
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) {
                    setModalState(() {
                      materialSeleccionado = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (materialSeleccionado == 'Otro...')
                  TextField(
                    controller: otroCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del material',
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de hojas',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final cantidad = int.tryParse(cantidadCtrl.text.trim()) ?? 0;
                  final material = materialSeleccionado == 'Otro...'
                      ? otroCtrl.text.trim()
                      : (materialSeleccionado ?? '');
                  if (cantidad <= 0 || material.isEmpty) return;

                  await StorageService.sumarInventario({material: cantidad});
                  await _cargar();
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarBorrarHistorial() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar historial'),
        content: const Text(
          'Se eliminara el historial de consumo y muebles terminados. '
          'El inventario no se borrara. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await StorageService.borrarHistorial();
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial borrado')),
      );
    }
  }

  Future<void> _editarInventario(String material) async {
    final actual = _inventario[material] ?? 0;
    final ctrl = TextEditingController(text: actual.toString());

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar inventario - $material'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Cantidad de hojas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final nuevo = int.tryParse(ctrl.text.trim());
              if (nuevo == null || nuevo < 0) return;
              final inventario = Map<String, int>.from(_inventario);
              if (nuevo == 0) {
                inventario.remove(material);
              } else {
                inventario[material] = nuevo;
              }
              await StorageService.guardarInventarioHojas(inventario);
              await _cargar();
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  List<String> _materialesDisponibles() {
    final comunes = [
      'MDF 15 mm',
      'MDF 12 mm',
      'MDF 9 mm',
      'Okume 15 mm',
      'Okume 12 mm',
      'Okume 4.5 mm',
      'Pino 9 mm',
      'Caobilla 2.5 mm',
      'Otro...',
    ];
    final set = <String>{..._inventario.keys};
    for (final week in _historial.values) {
      set.addAll(week.keys);
    }
    final lista = [...set, ...comunes].toSet().toList();
    lista.removeWhere((e) => e.isEmpty);
    lista.sort();
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final semanas = _historial.keys.toList();
    semanas.sort((a, b) => b.compareTo(a));
    final mensual = _agruparConsumoMensual(_historial);
    final meses = mensual.keys.toList()..sort((a, b) => b.compareTo(a));
    final semanasMuebles = _historialMuebles.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        title: const Text('Historial e inventario'),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        actions: [
          IconButton(
            tooltip: 'Borrar historial',
            icon: const Icon(Icons.delete_forever),
            onPressed: _confirmarBorrarHistorial,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Inventario de hojas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _agregarHojas,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_inventario.isEmpty)
                    Text(
                      'Sin inventario registrado.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ..._inventario.entries.map(
                      (e) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(e.key),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${e.value} hojas',
                                style:
                                    const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editarInventario(e.key),
                              ),
                            ],
                          ),
                          onTap: () => _editarInventario(e.key),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Consumo semanal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (semanas.isEmpty)
                    Text(
                      'Aun no hay consumo registrado.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ...semanas.map((weekKey) {
                      final consumo = _historial[weekKey] ?? {};
                      final rango = _formatoSemana(weekKey);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rango,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (consumo.isEmpty)
                                const Text('Sin consumo')
                              else
                                ...consumo.entries.map(
                                  (e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '- ${e.key}: ${e.value} hojas',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  const Text(
                    'Muebles terminados',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (semanasMuebles.isEmpty)
                    Text(
                      'Aun no hay muebles registrados.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ...semanasMuebles.map((weekKey) {
                      final muebles = _historialMuebles[weekKey] ?? {};
                      final rango = _formatoSemana(weekKey);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rango,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (muebles.isEmpty)
                                const Text('Sin muebles')
                              else
                                ...muebles.entries.map(
                                  (e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '- ${_formatoMueble(e.key)}: ${e.value}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  const Text(
                    'Consumo mensual',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (meses.isEmpty)
                    Text(
                      'Aun no hay consumo mensual.',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ...meses.map((monthKey) {
                      final consumo = mensual[monthKey] ?? {};
                      final titulo = _formatoMes(monthKey);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (consumo.isEmpty)
                                const Text('Sin consumo')
                              else
                                ...consumo.entries.map(
                                  (e) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '- ${e.key}: ${e.value} hojas',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}


Map<String, Map<String, int>> _agruparConsumoMensual(
  Map<String, Map<String, int>> historial,
) {
  final Map<String, Map<String, int>> mensual = {};
  for (final entry in historial.entries) {
    final inicio = DateTime.tryParse(entry.key);
    if (inicio == null) continue;
    final key = '${inicio.year.toString().padLeft(4, '0')}-'
        '${inicio.month.toString().padLeft(2, '0')}';
    final actual = Map<String, int>.from(mensual[key] ?? {});
    entry.value.forEach((material, cantidad) {
      actual[material] = (actual[material] ?? 0) + cantidad;
    });
    mensual[key] = actual;
  }
  return mensual;
}

String _formatoSemana(String weekKey) {
  final inicio = DateTime.tryParse(weekKey);
  if (inicio == null) return 'Semana $weekKey';
  final fin = inicio.add(const Duration(days: 6));
  return 'Semana ${_fmtDate(inicio)} - ${_fmtDate(fin)}';
}

String _formatoMueble(String key) {
  final parts = key.split('|');
  if (parts.length != 2) return key;
  return '${parts[0]} (${parts[1].replaceAll('x', ' × ')})';
}

String _formatoMes(String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return 'Mes $monthKey';
  return 'Mes ${parts[1]}/${parts[0]}';
}

String _fmtDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  return '$d/$m/$y';
}
