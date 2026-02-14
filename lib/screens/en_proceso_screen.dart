import 'package:flutter/material.dart';
import '../models/mueble.dart';
import '../models/material_mueble.dart';
import '../services/storage_service.dart';

class EnProcesoScreen extends StatefulWidget {
  final Mueble mueble;

  const EnProcesoScreen({super.key, required this.mueble});

  @override
  State<EnProcesoScreen> createState() => _EnProcesoScreenState();
}

class _EnProcesoScreenState extends State<EnProcesoScreen> {
  void _resetearChecklist() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reiniciar checklist'),
        content: const Text(
          'Se marcaran todos los materiales como pendientes. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (final parte in widget.mueble.partes) {
                  for (final material in parte.materiales) {
                    material['completado'] = false;
                  }
                }
              });
              StorageService.guardarMuebleIndividual(widget.mueble);
              Navigator.pop(context);
            },
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final materiales = widget.mueble.partes
        .expand((p) => p.materiales.map(MaterialMueble.fromMap))
        .toList();
    final totalMateriales = materiales.length;
    final completados = materiales.where((m) => m.completado).length;
    final progreso =
        totalMateriales == 0 ? 0.0 : completados / totalMateriales;
    final multiplicador = widget.mueble.cantidadEnProceso < 1
        ? 1
        : widget.mueble.cantidadEnProceso;

    return Scaffold(
      appBar: AppBar(
        title: const Text('En proceso'),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        backgroundColor: const Color(0xFF1B3A2F),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reiniciar checklist',
            onPressed: _resetearChecklist,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.mueble.nombre,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.factory, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'En proceso',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch(
                        value: widget.mueble.enProceso,
                        onChanged: (value) {
                          setState(() {
                            widget.mueble.enProceso = value;
                          });
                          StorageService.guardarMuebleIndividual(widget.mueble);
                        },
                      ),
                    ],
                  ),
                  if (widget.mueble.enProceso)
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Cantidad en proceso'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: widget.mueble.cantidadEnProceso > 1
                              ? () {
                                  setState(() {
                                    widget.mueble.cantidadEnProceso--;
                                  });
                                  StorageService.guardarMuebleIndividual(
                                    widget.mueble,
                                  );
                                }
                              : null,
                        ),
                        Text(
                          widget.mueble.cantidadEnProceso.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              widget.mueble.cantidadEnProceso++;
                            });
                            StorageService.guardarMuebleIndividual(
                              widget.mueble,
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
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
                      const Icon(Icons.insights, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Avance general',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$completados / $totalMateriales',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progreso,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade300,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          ...widget.mueble.partes.map((parte) {
            final materialesParte =
                parte.materiales.map(MaterialMueble.fromMap).toList();
            final totalParte = materialesParte.length;
            final completadosParte =
                materialesParte.where((m) => m.completado).length;
            final progresoParte =
                totalParte == 0 ? 0.0 : completadosParte / totalParte;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// NOMBRE DE LA PARTE
                    Text(
                      parte.nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progresoParte,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$completadosParte/$totalParte',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    /// LISTA DE MATERIALES
                    ...parte.materiales.map((m) {
                      final material = MaterialMueble.fromMap(m);
                      final completado = material.completado;
                      final cantidadMostrada =
                          material.cantidad * multiplicador;
                      final tituloStyle = TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration:
                            completado ? TextDecoration.lineThrough : null,
                        color:
                            completado ? Colors.grey.shade600 : Colors.black,
                      );
                      final medidasStyle = TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration:
                            completado ? TextDecoration.lineThrough : null,
                        color:
                            completado ? Colors.grey.shade600 : Colors.black,
                      );
                      final detalleStyle = TextStyle(
                        fontSize: 14,
                        color: completado
                            ? Colors.grey.shade500
                            : Colors.black54,
                        decoration:
                            completado ? TextDecoration.lineThrough : null,
                      );

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: completado,
                              activeColor: const Color(0xFF2E7D32),
                              onChanged: (value) {
                                setState(() {
                                  material.completado = value ?? false;
                                  m['completado'] = material.completado;
                                });

                                StorageService.guardarMuebleIndividual(
                                  widget.mueble,
                                );
                              },
                            ),

                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: completado
                                      ? const Color(0xFF2E7D32)
                                          .withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// TIPO + CANTIDAD
                                  Text(
                                    '$cantidadMostrada × ${material.tipo}',
                                    style: tituloStyle,
                                  ),

                                  const SizedBox(height: 4),

                                  /// MEDIDAS (LO MÁS IMPORTANTE)
                                  Text(
                                    '${material.largoCm} × ${material.anchoCm} cm',
                                    style: medidasStyle,
                                  ),

                                  /// MATERIAL (SOLO SI EXISTE)
                                  if (material.material != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '${material.material} • ${material.espesorMm} mm',
                                      style: detalleStyle,
                                    ),
                                  ],
                                ],
                              ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
