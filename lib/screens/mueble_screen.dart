import 'package:flutter/material.dart';
import '../models/mueble.dart';
import '../models/material_mueble.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/storage_service.dart';
import '../models/parte_mueble.dart';
import '../screens/en_proceso_screen.dart';

class MuebleScreen extends StatefulWidget {
  final Mueble mueble;

  const MuebleScreen({super.key, required this.mueble});

  @override
  State<MuebleScreen> createState() => _MuebleScreenState();
}

class _MuebleScreenState extends State<MuebleScreen> {
  int indexParte = 0;

  bool _esOkumeOPino(String? material) {
    if (material == null) return false;
    final valor = material.trim().toLowerCase();
    return valor == 'okume' || valor == 'pino';
  }

  bool _esMdf(String? material) {
    if (material == null) return false;
    return material.trim().toLowerCase() == 'mdf';
  }

  int _cantidadDesdeRaw(Map<String, dynamic> raw) {
    final cantidad = raw['cantidad'];
    if (cantidad is num) return cantidad.toInt();
    return 1;
  }

  Future<void> _convertirMaterialesMasivo({
    required String tituloDialogo,
    required String descripcionOrigen,
    required String materialDestino,
    required bool Function(String?) filtroOrigen,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tituloDialogo),
        content: Text(
          'Se cambiaran todos los materiales $descripcionOrigen a $materialDestino.\n'
          'Los espesores se conservaran.\n\n'
          'Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Convertir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    var cambios = 0;
    var piezas = 0;

    setState(() {
      for (final parte in widget.mueble.partes) {
        for (final raw in parte.materiales) {
          final materialActual = raw['material']?.toString();
          if (filtroOrigen(materialActual)) {
            raw['material'] = materialDestino;
            cambios++;
            piezas += _cantidadDesdeRaw(raw);
          }
        }
      }
    });

    if (cambios == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontraron materiales $descripcionOrigen para cambiar',
          ),
        ),
      );
      return;
    }

    await StorageService.guardarMuebleIndividual(widget.mueble);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Convertidos $cambios registros ($piezas piezas) a $materialDestino',
        ),
      ),
    );
  }

  Future<void> _convertirOkumePinoAMdf() async {
    await _convertirMaterialesMasivo(
      tituloDialogo: 'Convertir materiales a MDF',
      descripcionOrigen: 'Okume/Pino',
      materialDestino: 'MDF',
      filtroOrigen: _esOkumeOPino,
    );
  }

  Future<void> _convertirMdfAPino() async {
    await _convertirMaterialesMasivo(
      tituloDialogo: 'Convertir materiales a Pino',
      descripcionOrigen: 'MDF',
      materialDestino: 'Pino',
      filtroOrigen: _esMdf,
    );
  }

  void _eliminarParte(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar parte'),
        content: const Text(
          'Se eliminará la parte y todos sus materiales.\n¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.mueble.partes.removeAt(index);

                // Si se borra la parte activa
                if (indexParte >= widget.mueble.partes.length) {
                  indexParte = 0;
                }
              });

              StorageService.guardarMuebleIndividual(widget.mueble);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editarParte(int index) {
    final ctrl = TextEditingController(
      text: widget.mueble.partes[index].nombre,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar nombre de la parte'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre de la parte'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nuevoNombre = ctrl.text.trim();

              if (nuevoNombre.isEmpty) return;

              setState(() {
                widget.mueble.partes[index].nombre = nuevoNombre;
              });

              StorageService.guardarMuebleIndividual(widget.mueble);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarMenuParte(int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar nombre'),
              onTap: () {
                Navigator.pop(context);
                _editarParte(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Eliminar parte'),
              onTap: () {
                Navigator.pop(context);
                _eliminarParte(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarAgregarParte() {
    final TextEditingController nombreParteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva parte'),
        content: TextField(
          controller: nombreParteCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de la parte',
            border: OutlineInputBorder(),
          ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            child: const Text('Agregar parte'),
            onPressed: () {
              final nombreParte = nombreParteCtrl.text.trim();

              if (nombreParte.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Escribe el nombre de la parte'),
                  ),
                );
                return;
              }

              setState(() {
                // 🔥 elimina "General" si es la única
                if (widget.mueble.partes.length == 1 &&
                    widget.mueble.partes.first.nombre == 'General') {
                  widget.mueble.partes.clear();
                }

                widget.mueble.partes.add(ParteMueble(nombre: nombreParte));
              });

              StorageService.guardarMuebleIndividual(widget.mueble);

              Navigator.pop(context); // 👈 CERRAR DESPUÉS DE AGREGAR
            },
          ),
        ],
      ),
    );
  }

  void _eliminarMaterial(int index) {
    setState(() {
      widget.mueble.partes[indexParte].materiales.removeAt(index);
    });

    // 👇 guarda si ya tienes persistencia
    StorageService.guardarMuebleIndividual(widget.mueble);
  }

  void _mostrarMenuMaterial(int index) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar material'),
                onTap: () {
                  Navigator.pop(context);
                  _eliminarMaterial(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _eliminarImagen(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar imagen'),
        content: const Text('¿Deseas eliminar esta foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.mueble.imagenesMateriales.removeAt(index);
              });
              StorageService.guardarMuebleIndividual(widget.mueble);
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _verImagenGrande(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(child: Image.file(File(path))),
      ),
    );
  }

  Future<void> _agregarFotoLibreta() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);

    if (picked == null) return;

    setState(() {
      widget.mueble.imagenesMateriales.add(picked.path);
    });

    // guarda cambios
    await StorageService.guardarMuebleIndividual(widget.mueble);
  }

  /*void _mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red.shade700),
    );
  }*/

  void _mostrarAgregarMaterial({int? indexEditar}) {
    MaterialMueble? materialEditando;

    if (indexEditar != null) {
      materialEditando = MaterialMueble.fromMap(
        widget.mueble.partes[indexParte].materiales[indexEditar],
      );
    }

    double largo = materialEditando?.largoCm ?? 0;
    double ancho = materialEditando?.anchoCm ?? 0;
    int cantidad = materialEditando?.cantidad ?? 1;

    const otroTipoLabel = 'Otro...';
    final tipos = [
      'Tiras de madera',
      'Paredes del Mueble',
      'Entrepaños',
      'Cajones',
      'Tapaderas de Cajones',
      'Puertas grandes',
      'Puertas chicas',
      'Tapas traseras',
      otroTipoLabel,
    ];

    final materialesDisponibles = ['MDF', 'Pino', 'Okume', 'Caobilla'];

    final Map<String, List<double>> espesores = {
      'MDF': [9.0, 12.0, 15.0],
      'Pino': [9.0],
      'Okume': [4.5, 12.0, 15.0],
      'Caobilla': [2.5],
    };

    if (indexEditar != null) {
      materialEditando = MaterialMueble.fromMap(
        widget.mueble.partes[indexParte].materiales[indexEditar],
      );
    }

    final largoCtrl = TextEditingController(
      text: materialEditando?.largoCm.toString() ?? '',
    );
    final anchoCtrl = TextEditingController(
      text: materialEditando?.anchoCm.toString() ?? '',
    );
    String? tipoSeleccionado = tipos.contains(materialEditando?.tipo)
        ? materialEditando!.tipo
        : (materialEditando != null ? otroTipoLabel : null);
    final tipoPersonalizadoCtrl = TextEditingController(
      text: tipos.contains(materialEditando?.tipo)
          ? ''
          : (materialEditando?.tipo ?? ''),
    );
    String? materialSeleccionado =
        materialesDisponibles.contains(materialEditando?.material)
        ? materialEditando!.material
        : null;
    double? espesorSeleccionado;

    if (materialSeleccionado != null &&
        espesores[materialSeleccionado]!.contains(
          materialEditando?.espesorMm,
        )) {
      espesorSeleccionado = materialEditando!.espesorMm;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Agregar material',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: tipoSeleccionado,
                      hint: const Text('Tiras de madera'),
                      decoration: const InputDecoration(
                        labelText: 'Tipo de pieza',
                      ),
                      items: tipos.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t));
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          tipoSeleccionado = value;
                          materialSeleccionado = null;
                          espesorSeleccionado = null;
                          if (tipoSeleccionado != otroTipoLabel) {
                            tipoPersonalizadoCtrl.clear();
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    if (tipoSeleccionado == otroTipoLabel) ...[
                      TextField(
                        controller: tipoPersonalizadoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de pieza',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (tipoSeleccionado != null &&
                        tipoSeleccionado != 'Tiras de madera') ...[
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: materialSeleccionado,
                        hint: const Text('Selecciona material'),
                        decoration: const InputDecoration(
                          labelText: 'Material',
                        ),
                        items: materialesDisponibles.map((m) {
                          return DropdownMenuItem(value: m, child: Text(m));
                        }).toList(),
                        onChanged: (value) {
                          setModalState(() {
                            materialSeleccionado = value;
                            espesorSeleccionado = null;
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    if (tipoSeleccionado != null &&
                        tipoSeleccionado != 'Tiras de madera' &&
                        materialSeleccionado != null)
                      DropdownButtonFormField<double>(
                        value: espesorSeleccionado,
                        hint: const Text('Selecciona espesor'),
                        decoration: const InputDecoration(labelText: 'Espesor'),
                        items: espesores[materialSeleccionado]!
                            .map(
                              (e) => DropdownMenuItem<double>(
                                value: e,
                                child: Text('$e mm'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setModalState(() {
                            espesorSeleccionado = value;
                          });
                        },
                      ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: largoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Largo (cm)',
                      ),
                      onChanged: (v) => largo = double.tryParse(v) ?? largo,
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: anchoCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ancho (cm)',
                      ),
                      onChanged: (v) => ancho = double.tryParse(v) ?? ancho,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Text('Cantidad'),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            setModalState(() {
                              if (cantidad > 1) cantidad--;
                            });
                          },
                        ),
                        Text(
                          cantidad.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setModalState(() {
                              cantidad++;
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () {
                        // VALIDACIÓN TIPO
                        if (tipoSeleccionado == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Selecciona el tipo')),
                          );
                          return;
                        }

                        if (tipoSeleccionado == otroTipoLabel &&
                            tipoPersonalizadoCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Escribe el nombre de la pieza'),
                            ),
                          );
                          return;
                        }

                        // VALIDACIONES SOLO SI NO ES TIRA
                        if (tipoSeleccionado != 'Tiras de madera') {
                          if (materialSeleccionado == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecciona el material'),
                              ),
                            );
                            return;
                          }

                          if (espesorSeleccionado == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Selecciona el espesor'),
                              ),
                            );
                            return;
                          }
                        }

                        final nuevoMaterial = MaterialMueble(
                          tipo: tipoSeleccionado == otroTipoLabel
                              ? tipoPersonalizadoCtrl.text.trim()
                              : tipoSeleccionado!,
                          material: tipoSeleccionado == 'Tiras de madera'
                              ? null
                              : materialSeleccionado,
                          espesorMm: tipoSeleccionado == 'Tiras de madera'
                              ? null
                              : espesorSeleccionado,
                          largoCm: largo,
                          anchoCm: ancho,
                          cantidad: cantidad,
                          completado: materialEditando?.completado ?? false,
                        );

                        setState(() {
                          if (indexEditar != null) {
                            widget
                                .mueble
                                .partes[indexParte]
                                .materiales[indexEditar] = nuevoMaterial
                                .toMap();
                          } else {
                            widget.mueble.partes[indexParte].materiales.add(
                              nuevoMaterial.toMap(),
                            );
                          }
                        });

                        StorageService.guardarMuebleIndividual(widget.mueble);
                        Navigator.pop(context);
                      },

                      child: const Text('Guardar material'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Color.fromARGB(255, 255, 255, 255)),
        onPressed: () {
          _mostrarAgregarMaterial();
        },
      ),

      body: CustomScrollView(
        slivers: [
          /// HEADER CON IMAGEN DEL MUEBLE
          SliverAppBar(
            backgroundColor: const Color(0xFF1B3A2F),
            expandedHeight: 260,
            pinned: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.swap_horiz,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                tooltip: 'Okume/Pino -> MDF',
                onPressed: _convertirOkumePinoAMdf,
              ),
              IconButton(
                icon: const Icon(
                  Icons.swap_horizontal_circle,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                tooltip: 'MDF -> Pino',
                onPressed: _convertirMdfAPino,
              ),
              IconButton(
                icon: const Icon(
                  Icons.playlist_add_check,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                tooltip: 'En proceso',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EnProcesoScreen(mueble: widget.mueble),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.mueble.nombre,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
              ),
              background: widget.mueble.imagePath != null
                  ? Image.file(
                      File(widget.mueble.imagePath!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: const Color(0xFF1B3A2F),
                      child: const Center(
                        child: Icon(
                          Icons.chair_alt,
                          size: 80,
                          color: Colors.white54,
                        ),
                      ),
                    ),
            ),
          ),

          /// MEDIDAS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Medidas: ${widget.mueble.anchoCm} × ${widget.mueble.altoCm} × ${widget.mueble.fondoCm} cm',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
          ),

          /// ESTADO EN PROCESO
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                              StorageService.guardarMuebleIndividual(
                                widget.mueble,
                              );
                            },
                          ),
                        ],
                      ),
                      if (widget.mueble.enProceso)
                        Row(
                          children: [
                            const Expanded(child: Text('Cantidad en proceso')),
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
            ),
          ),

          /// FOTOS DE LIBRETA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📓 Fotos de la libreta',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Agregar foto'),
                    onPressed: _agregarFotoLibreta,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: widget.mueble.imagenesMateriales.isEmpty
                        ? const Center(child: Text('No hay fotos aún'))
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.mueble.imagenesMateriales.length,
                            itemBuilder: (context, index) {
                              final path =
                                  widget.mueble.imagenesMateriales[index];
                              return GestureDetector(
                                onTap: () => _verImagenGrande(path),
                                onLongPress: () => _eliminarImagen(index),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(File(path)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: List.generate(widget.mueble.partes.length, (i) {
                  final parte = widget.mueble.partes[i];
                  final seleccionada = i == indexParte;

                  return GestureDetector(
                    onLongPress: () => _mostrarMenuParte(i),
                    child: ChoiceChip(
                      label: Text(parte.nombre),
                      selected: seleccionada,
                      selectedColor: const Color(0xFF2E7D32),
                      labelStyle: TextStyle(
                        color: seleccionada ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) {
                        setState(() {
                          indexParte = i;
                        });
                      },
                    ),
                  );
                }),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar parte'),
                onPressed: _mostrarAgregarParte,
              ),
            ),
          ),

          /// TÍTULO MATERIALES
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Materiales – ${widget.mueble.partes[indexParte].nombre}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          /// LISTA DE MATERIALES
          widget.mueble.partes[indexParte].materiales.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No hay materiales aún'),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final material = MaterialMueble.fromMap(
                        widget.mueble.partes[indexParte].materiales[index],
                      );

                      return GestureDetector(
                        onLongPress: () => _mostrarMenuMaterial(index),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// CABECERA MATERIAL
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${material.cantidad} × ${material.tipo}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Color(0xFF2E7D32),
                                      ),
                                      tooltip: 'Editar material',
                                      onPressed: () {
                                        _mostrarAgregarMaterial(
                                          indexEditar: index,
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                /// MATERIAL Y ESPESOR
                                if (material.material != null)
                                  Text(
                                    '${material.material} • ${material.espesorMm} mm',
                                    style: const TextStyle(fontSize: 16),
                                  ),

                                const SizedBox(height: 4),

                                /// MEDIDAS
                                Text(
                                  'Medidas: ${material.largoCm} × ${material.anchoCm} cm',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount:
                        widget.mueble.partes[indexParte].materiales.length,
                  ),
                ),
        ],
      ),
    );
  }
}
