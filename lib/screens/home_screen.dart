import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../models/mueble.dart';
import '../models/material_mueble.dart';
import '../models/parte_mueble.dart';
import 'mueble_screen.dart';
import '../services/storage_service.dart';
import '../screens/en_proceso_screen.dart';
import '../screens/produccion_screen.dart';
import '../screens/calculadora_screen.dart';
import '../screens/calculadora_cortes_screen.dart';
import '../screens/calculadora_puertas_cajones_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum HomeVistaModo { gridGrande, gridCompacta, lista }

class HomeScreen extends StatefulWidget {
  final List<Mueble> muebles;

  const HomeScreen({super.key, required this.muebles});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController anchoCtrl = TextEditingController();
  final TextEditingController altoCtrl = TextEditingController();
  final TextEditingController fondoCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  File? imagenSeleccionada;
  String filtro = '';
  List<Mueble> muebles = [];
  HomeVistaModo _vistaModo = HomeVistaModo.gridGrande;
  bool _mostrarBarraBusqueda = false;
  @override
  void initState() {
    super.initState();
    _cargarMuebles();
  }

  Future<void> _cargarMuebles() async {
    final cargados = await StorageService.cargarMuebles();
    setState(() {
      muebles = cargados;
    });
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    anchoCtrl.dispose();
    altoCtrl.dispose();
    fondoCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _cerrarTeclado() {
    FocusScope.of(context).unfocus();
  }

  void _toggleBarraBusqueda() {
    if (_mostrarBarraBusqueda) {
      setState(() {
        _mostrarBarraBusqueda = false;
        filtro = '';
      });
      _searchCtrl.clear();
      _cerrarTeclado();
      return;
    }
    setState(() => _mostrarBarraBusqueda = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_searchFocus);
      }
    });
  }

  Future<void> _abrirMenuSuperior(String value) async {
    switch (value) {
      case 'calculadora':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalculadoraScreen()),
        );
        break;
      case 'calculadora_cortes':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CalculadoraCortesScreen()),
        );
        break;
      case 'calculadora_puertas':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CalculadoraPuertasCajonesScreen(),
          ),
        );
        break;
      case 'backup_exportar':
        await _exportarBackup();
        break;
      case 'backup_importar':
        await _importarBackup();
        break;
      case 'pdf_produccion':
        await _generarPdfProduccion();
        break;
    }
  }

  Future<void> _abrirDesdeMenuLateral(String action) async {
    Navigator.of(context).pop();
    await _abrirMenuSuperior(action);
  }

  Widget _buildMenuLateral() {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: const Color(0xFF1B3A2F),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Calculadora'),
              onTap: () => _abrirDesdeMenuLateral('calculadora'),
            ),
            ListTile(
              leading: const Icon(Icons.content_cut),
              title: const Text('Calculadora de cortes'),
              onTap: () => _abrirDesdeMenuLateral('calculadora_cortes'),
            ),
            ListTile(
              leading: const Icon(Icons.door_sliding),
              title: const Text('Puertas y cajones'),
              onTap: () => _abrirDesdeMenuLateral('calculadora_puertas'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Exportar backup'),
              onTap: () => _abrirDesdeMenuLateral('backup_exportar'),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Restaurar backup'),
              onTap: () => _abrirDesdeMenuLateral('backup_importar'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF de produccion'),
              onTap: () => _abrirDesdeMenuLateral('pdf_produccion'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportarBackup() async {
    final backup = await StorageService.exportarBackup();
    final jsonTexto = const JsonEncoder.withIndent('  ').convert(backup);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/recetario_backup_$stamp.json');
    await file.writeAsString(jsonTexto);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Backup de Recetario El Alamo',
      subject: 'backup_recetario',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup exportado correctamente')),
    );
  }

  Future<void> _importarBackup() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: const Text(
          'Esto reemplazara los datos actuales de la app. Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: false,
    );

    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;

    try {
      final contenido = await File(path).readAsString();
      final dynamic parsed = jsonDecode(contenido);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Formato de backup invalido');
      }
      await StorageService.importarBackup(parsed);
      await _cargarMuebles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado correctamente')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo restaurar el backup')),
      );
    }
  }

  Future<void> _generarPdfProduccion() async {
    final enProceso = muebles.where((m) => m.enProceso).toList();
    if (enProceso.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay muebles en proceso para PDF')),
      );
      return;
    }

    final gruposMuebles = _pdfAgruparMuebles(enProceso);
    final materialesAcumulados = _pdfAgruparMateriales(enProceso);
    final materialesPuertas = materialesAcumulados
        .where((m) => _pdfTiposPuertasCajones.contains(m.material.tipo))
        .toList();
    final materialesGenerales = materialesAcumulados
        .where((m) => !_pdfTiposPuertasCajones.contains(m.material.tipo))
        .toList();
    final gruposMateriales = _pdfAgruparMaterialesGlobal(materialesGenerales);
    final gruposPuertas = _pdfAgruparPuertasCajones(materialesPuertas);

    final doc = pw.Document();
    final fecha = DateTime.now();
    final fechaTexto =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    pw.Widget sectionTitle(String text) {
      return pw.Text(
        text,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      );
    }

    pw.Widget muebleCard(_PdfGrupoMueble grupo) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    grupo.nombre,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        const pw.TextSpan(text: 'Medidas: '),
                        pw.TextSpan(
                          text: grupo.medidas,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'x ${grupo.cantidad}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      );
    }

    pw.Widget materialLine(_PdfMaterialLinea item) {
      final baseStyle = pw.TextStyle(
        fontSize: 11,
        color: item.completado ? PdfColors.grey700 : PdfColors.black,
        decoration: item.completado
            ? pw.TextDecoration.lineThrough
            : pw.TextDecoration.none,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            style: baseStyle,
            children: [
              pw.TextSpan(
                text:
                    '- ${item.cantidad} ${item.cantidad == 1 ? 'pieza' : 'piezas'} - ',
              ),
              pw.TextSpan(
                text: '${_pdfFmt(item.largoCm)} x ${_pdfFmt(item.anchoCm)} cm',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: item.completado ? PdfColors.grey700 : PdfColors.black,
                  decoration: item.completado
                      ? pw.TextDecoration.lineThrough
                      : pw.TextDecoration.none,
                ),
              ),
              if (item.tipo.isNotEmpty) pw.TextSpan(text: ' (${item.tipo})'),
            ],
          ),
        ),
      );
    }

    pw.Widget materialCard(_PdfMaterialGrupo grupo) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    grupo.titulo,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (grupo.hojas != null)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#E6F4EA'),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                    ),
                    child: pw.Text(
                      '${grupo.hojas} hojas',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                        color: PdfColor.fromHex('#1B5E20'),
                      ),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 0.8),
            ...grupo.items.map(materialLine),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Produccion del dia',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Fecha: $fechaTexto'),
          pw.SizedBox(height: 16),
          sectionTitle('Muebles en proceso'),
          pw.SizedBox(height: 8),
          if (gruposMuebles.isEmpty)
            pw.Text('No hay muebles en proceso.')
          else
            ...gruposMuebles.map(muebleCard),
          pw.SizedBox(height: 14),
          sectionTitle('Materiales a cortar'),
          pw.SizedBox(height: 8),
          if (gruposMateriales.isEmpty)
            pw.Text('No hay materiales pendientes.')
          else
            ...gruposMateriales.map(materialCard),
          pw.SizedBox(height: 16),
          pw.Container(height: 6, color: PdfColors.grey400),
          pw.SizedBox(height: 12),
          sectionTitle('Puertas y/o cajones (15 mm)'),
          pw.SizedBox(height: 8),
          if (gruposPuertas.isEmpty)
            pw.Text('No hay puertas ni cajones pendientes.')
          else
            ...gruposPuertas.map(materialCard),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _cambiarImagenMueble(Mueble mueble) async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('GalerÃ­a'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('CÃ¡mara'),
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
      mueble.imagePath = picked.path;
    });

    await StorageService.guardarMuebles(muebles);
  }

  void _mostrarModalMueble({required bool esEdicion, Mueble? muebleEditando}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    Text(
                      esEdicion ? 'Editar mueble' : 'Nuevo mueble',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del mueble',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: anchoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ancho (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: altoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Alto (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: fondoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fondo (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final nombre = nombreCtrl.text.trim();
                        final ancho = double.tryParse(anchoCtrl.text);
                        final alto = double.tryParse(altoCtrl.text);
                        final fondo = double.tryParse(fondoCtrl.text);

                        if (nombre.isEmpty ||
                            ancho == null ||
                            alto == null ||
                            fondo == null) {
                          _mostrarError('Completa todos los campos');
                          return;
                        }

                        setState(() {
                          if (esEdicion && muebleEditando != null) {
                            // âœï¸ EDITAR
                            muebleEditando.nombre = nombre;
                            muebleEditando.anchoCm = ancho;
                            muebleEditando.altoCm = alto;
                            muebleEditando.fondoCm = fondo;
                            muebleEditando.imagePath = imagenSeleccionada?.path;
                          } else {
                            // âž• CREAR
                            muebles.add(
                              Mueble(
                                nombre: nombre,
                                anchoCm: ancho,
                                altoCm: alto,
                                fondoCm: fondo,
                                imagePath: imagenSeleccionada?.path,
                              ),
                            );
                          }
                        });
                        StorageService.guardarMuebles(muebles);

                        // limpiar
                        nombreCtrl.clear();
                        anchoCtrl.clear();
                        altoCtrl.clear();
                        fondoCtrl.clear();
                        imagenSeleccionada = null;

                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                      child: Text(
                        esEdicion ? 'Guardar cambios' : 'Crear mueble',
                        style: const TextStyle(fontSize: 16),
                      ),
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

  void _editarMueble(Mueble mueble) {
    // precargar los controladores
    nombreCtrl.text = mueble.nombre;
    anchoCtrl.text = mueble.anchoCm.toString();
    altoCtrl.text = mueble.altoCm.toString();
    fondoCtrl.text = mueble.fondoCm.toString();
    imagenSeleccionada = mueble.imagePath != null
        ? File(mueble.imagePath!)
        : null;

    _mostrarModalMueble(esEdicion: true, muebleEditando: mueble);
  }

  void _confirmarEliminar(Mueble mueble) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar mueble'),
          content: Text(
            'Â¿Seguro que deseas eliminar "${mueble.nombre}"?\n\n'
            'Esta acciÃ³n no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context); // cancelar
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  muebles.remove(mueble);
                });
                StorageService.guardarMuebles(muebles);

                FocusScope.of(context).unfocus();
                Navigator.pop(context); // cerrar diÃ¡logo
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _duplicarMueble(Mueble mueble) {
    final nuevoNombre = _generarNombreDuplicado(mueble.nombre);

    final partesDuplicadas = mueble.partes.map((parte) {
      final materiales = parte.materiales.map((m) {
        final copia = Map<String, dynamic>.from(m);
        copia['completado'] = false;
        return copia;
      }).toList();
      return ParteMueble(nombre: parte.nombre, materiales: materiales);
    }).toList();

    final duplicado = Mueble(
      nombre: nuevoNombre,
      anchoCm: mueble.anchoCm,
      altoCm: mueble.altoCm,
      fondoCm: mueble.fondoCm,
      imagePath: mueble.imagePath,
      partes: partesDuplicadas,
      imagenesMateriales: List<String>.from(mueble.imagenesMateriales),
      enProceso: false,
      cantidadEnProceso: 1,
    );

    setState(() {
      muebles.add(duplicado);
    });

    StorageService.guardarMuebles(muebles);
  }

  String _generarNombreDuplicado(String base) {
    var nombre = '$base (copia)';
    var contador = 2;
    final existentes = muebles.map((m) => m.nombre).toSet();

    while (existentes.contains(nombre)) {
      nombre = '$base (copia $contador)';
      contador++;
    }

    return nombre;
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  void _crearMuebleBasico() {
    final nombreCtrl = TextEditingController();
    final anchoCtrl = TextEditingController();
    final altoCtrl = TextEditingController();
    final fondoCtrl = TextEditingController();
    File? imagenSeleccionada;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const Text(
                      'Nuevo mueble',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Agrega la informaciÃ³n bÃ¡sica del mueble',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();

                        final source = await showModalBottomSheet<ImageSource>(
                          context: context,
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.photo),
                                  title: const Text('GalerÃ­a'),
                                  onTap: () => Navigator.pop(
                                    context,
                                    ImageSource.gallery,
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('CÃ¡mara'),
                                  onTap: () => Navigator.pop(
                                    context,
                                    ImageSource.camera,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (source == null) return;

                        final picked = await picker.pickImage(
                          source: source,
                          imageQuality: 80,
                        );

                        if (picked != null) {
                          setModalState(() {
                            imagenSeleccionada = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.grey.shade200,
                        ),
                        child: imagenSeleccionada != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                  imagenSeleccionada!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, size: 40),
                                  SizedBox(height: 8),
                                  Text('Agregar imagen (opcional)'),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      textInputAction: TextInputAction.next,
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del mueble',
                        prefixIcon: Icon(Icons.chair_alt),
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            textInputAction: TextInputAction.next,
                            controller: anchoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Ancho (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            textInputAction: TextInputAction.next,
                            controller: altoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Alto (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            textInputAction: TextInputAction.done,
                            controller: fondoCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Fondo (cm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        // VALIDAR
                        if (nombreCtrl.text.trim().isEmpty) {
                          _mostrarError('Escribe el nombre del mueble');
                          return;
                        }

                        final ancho = double.tryParse(anchoCtrl.text);
                        final alto = double.tryParse(altoCtrl.text);
                        final fondo = double.tryParse(fondoCtrl.text);

                        if (ancho == null || alto == null || fondo == null) {
                          _mostrarError('Completa correctamente las medidas');
                          return;
                        }

                        // CREAR MUEBLE
                        setState(() {
                          muebles.add(
                            Mueble(
                              nombre: nombreCtrl.text.trim(),
                              anchoCm: ancho,
                              altoCm: alto,
                              fondoCm: fondo,
                              imagePath: imagenSeleccionada?.path,
                            ),
                          );
                        });

                        // GUARDAR
                        StorageService.guardarMuebles(muebles);

                        // LIMPIAR
                        nombreCtrl.clear();
                        anchoCtrl.clear();
                        altoCtrl.clear();
                        fondoCtrl.clear();
                        imagenSeleccionada = null;

                        // CERRAR MODAL
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },

                      child: const Text(
                        'Crear mueble',
                        style: TextStyle(fontSize: 16),
                      ),
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

  void _mostrarOpcionesNuevoMueble(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.add_box),
                title: const Text('Nuevo mueble'),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _crearMuebleBasico();
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  /*Widget _opcionSheet({
    required IconData icon,
    required String texto,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        texto,
        style: TextStyle(
          fontSize: 16,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }*/

  int _crossAxisCountForMode(bool isWide) {
    if (_vistaModo == HomeVistaModo.gridCompacta) {
      return isWide ? 5 : 3;
    }
    return isWide ? 3 : 2;
  }

  IconData _iconoVistaActual() {
    switch (_vistaModo) {
      case HomeVistaModo.gridGrande:
        return Icons.grid_view_rounded;
      case HomeVistaModo.gridCompacta:
        return Icons.grid_on_rounded;
      case HomeVistaModo.lista:
        return Icons.view_list_rounded;
    }
  }

  Widget _buildBotonVista() {
    return PopupMenuButton<HomeVistaModo>(
      tooltip: 'Cambiar vista',
      initialValue: _vistaModo,
      onSelected: (modo) {
        setState(() => _vistaModo = modo);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: HomeVistaModo.gridGrande,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.grid_view_rounded),
            title: Text('Cuadricula grande'),
          ),
        ),
        PopupMenuItem(
          value: HomeVistaModo.gridCompacta,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.grid_on_rounded),
            title: Text('Cuadricula compacta'),
          ),
        ),
        PopupMenuItem(
          value: HomeVistaModo.lista,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.view_list_rounded),
            title: Text('Lista sin imagen'),
          ),
        ),
      ],
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(_iconoVistaActual(), color: const Color(0xFF1B3A2F)),
      ),
    );
  }

  Widget _buildBusquedaExpandible({required bool expandida}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 56,
      width: expandida ? null : 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleBarraBusqueda,
            icon: Icon(
              expandida ? Icons.close_rounded : Icons.search,
              color: const Color(0xFF1B3A2F),
            ),
          ),
          if (expandida)
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: expandida ? 1 : 0,
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  onChanged: (value) {
                    setState(() => filtro = value);
                  },
                  onTapOutside: (_) => _cerrarTeclado(),
                  decoration: const InputDecoration(
                    hintText: 'Buscar mueble...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          if (expandida) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBotonProduccion() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B3A2F),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          _cerrarTeclado();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProduccionScreen()),
          ).then((_) {
            _cerrarTeclado();
            _cargarMuebles();
          });
        },
        icon: const Icon(Icons.factory, color: Colors.white),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Produccion del dia',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _abrirEnProcesoDesdeHome(Mueble mueble) {
    _cerrarTeclado();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EnProcesoScreen(mueble: mueble)),
    ).then((_) {
      _cerrarTeclado();
      setState(() {});
    });
  }

  void _abrirEdicionMuebleDesdeHome(Mueble mueble) {
    _cerrarTeclado();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MuebleScreen(mueble: mueble)),
    ).then((_) {
      _cerrarTeclado();
      setState(() {});
    });
  }

  void _mostrarMenuMuebleHome(Mueble mueble) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Editar mueble'),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _editarMueble(mueble);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.green),
                title: const Text('Cambiar imagen'),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _cambiarImagenMueble(mueble);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.deepPurple),
                title: const Text('Duplicar mueble'),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _duplicarMueble(mueble);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar mueble'),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _confirmarEliminar(mueble);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMuebleGridCard(Mueble mueble) {
    return GestureDetector(
      onLongPress: () => _mostrarMenuMuebleHome(mueble),
      onTap: () => _abrirEnProcesoDesdeHome(mueble),
      child: Card(
        elevation: 4,
        color: mueble.enProceso ? const Color(0xFFE6F4EA) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: mueble.imagePath != null
                        ? Image.file(
                            File(mueble.imagePath!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                  if (mueble.enProceso)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'En proceso',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _abrirEdicionMuebleDesdeHome(mueble),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mueble.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${mueble.anchoCm} x ${mueble.altoCm} x ${mueble.fondoCm} cm',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuebleListTile(Mueble mueble) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 3,
      color: mueble.enProceso ? const Color(0xFFE6F4EA) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _abrirEnProcesoDesdeHome(mueble),
        onLongPress: () => _mostrarMenuMuebleHome(mueble),
        leading: Icon(
          mueble.enProceso ? Icons.playlist_add_check : Icons.chair_alt,
          color: const Color(0xFF1B3A2F),
        ),
        title: Text(
          mueble.nombre,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${mueble.anchoCm} x ${mueble.altoCm} x ${mueble.fondoCm} cm',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mueble.enProceso)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'En proceso',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Editar mueble',
              icon: const Icon(Icons.edit),
              onPressed: () => _abrirEdicionMuebleDesdeHome(mueble),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListadoMuebles(
    List<Mueble> mueblesFiltrados, {
    required bool isWide,
  }) {
    if (_vistaModo == HomeVistaModo.lista) {
      return ListView.builder(
        itemCount: mueblesFiltrados.length,
        itemBuilder: (context, index) {
          final mueble = mueblesFiltrados[index];
          return _buildMuebleListTile(mueble);
        },
      );
    }

    final childAspectRatio = _vistaModo == HomeVistaModo.gridCompacta
        ? (isWide ? 0.95 : 0.88)
        : 0.72;

    return GridView.builder(
      itemCount: mueblesFiltrados.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCountForMode(isWide),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final mueble = mueblesFiltrados[index];
        return _buildMuebleGridCard(mueble);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mueblesFiltrados = muebles
        .where((m) => m.nombre.toLowerCase().contains(filtro.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color.fromARGB(
        255,
        131,
        151,
        131,
      ), // fondo verde claro
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        centerTitle: true,
        elevation: 0,
        title: const Column(
          children: [
            Text(
              'Recetario',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            Text(
              'El Alamo',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),

        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildMenuLateral(),

      /// ðŸ§± CONTENIDO
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _cerrarTeclado,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final leftPanel = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      if (_mostrarBarraBusqueda)
                        Expanded(
                          child: _buildBusquedaExpandible(expandida: true),
                        )
                      else
                        _buildBusquedaExpandible(expandida: false),
                      if (!_mostrarBarraBusqueda) const SizedBox(width: 10),
                      if (!_mostrarBarraBusqueda)
                        Expanded(child: _buildBotonProduccion()),
                      const SizedBox(width: 10),
                      _buildBotonVista(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildListadoMuebles(
                      mueblesFiltrados,
                      isWide: isWide,
                    ),
                  ),
                ),
              ],
            );
            if (!isWide) {
              return leftPanel;
            }
            return Row(
              children: [
                Expanded(flex: 6, child: leftPanel),
                Expanded(flex: 4, child: _buildHomeSidePanel()),
              ],
            );
          },
        ),
      ),

      /// âž• BOTÃ“N AGREGAR
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.add, color: Color.fromARGB(255, 255, 255, 255)),
        onPressed: () {
          nombreCtrl.clear();
          anchoCtrl.clear();
          altoCtrl.clear();
          fondoCtrl.clear();
          imagenSeleccionada = null;

          _mostrarOpcionesNuevoMueble(context);
        },
      ),
    );
  }

  Widget _buildHomeSidePanel() {
    final enProceso = muebles.where((m) => m.enProceso).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      child: ListView(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Total muebles: ${muebles.length}'),
                  Text('En proceso: ${enProceso.length}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'En proceso',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (enProceso.isEmpty)
            Text(
              'No hay muebles en proceso.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...enProceso.map(
              (m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.playlist_add_check),
                  title: Text(m.nombre),
                  subtitle: Text(
                    '${m.anchoCm} Ã— ${m.altoCm} Ã— ${m.fondoCm} cm',
                  ),
                  trailing: Text('x ${m.cantidadEnProceso}'),
                  onTap: () {
                    _cerrarTeclado();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EnProcesoScreen(mueble: m),
                      ),
                    ).then((_) {
                      _cerrarTeclado();
                      _cargarMuebles();
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PdfGrupoMueble {
  final List<Mueble> muebles;
  final String nombre;
  final double anchoCm;
  final double altoCm;
  final double fondoCm;
  final int cantidad;

  _PdfGrupoMueble(this.muebles)
    : nombre = muebles.first.nombre,
      anchoCm = muebles.first.anchoCm,
      altoCm = muebles.first.altoCm,
      fondoCm = muebles.first.fondoCm,
      cantidad = muebles.fold<int>(
        0,
        (sum, m) => sum + _pdfCantidadValida(m.cantidadEnProceso),
      );

  String get medidas =>
      '${_pdfFmt(anchoCm)} x ${_pdfFmt(altoCm)} x ${_pdfFmt(fondoCm)} cm';
}

class _PdfMaterialGrupo {
  final String titulo;
  final List<_PdfMaterialLinea> items;
  final int? hojas;

  _PdfMaterialGrupo({
    required this.titulo,
    required this.items,
    required this.hojas,
  });
}

class _PdfMaterialLinea {
  final int cantidad;
  final double largoCm;
  final double anchoCm;
  final String tipo;
  final bool completado;

  _PdfMaterialLinea({
    required this.cantidad,
    required this.largoCm,
    required this.anchoCm,
    required this.tipo,
    required this.completado,
  });
}

class _PdfMaterialAcumulado {
  final MaterialMueble material;
  int total;
  int completadas;

  _PdfMaterialAcumulado({
    required this.material,
    required this.total,
    required this.completadas,
  });

  int get pendientes => total - completadas;
}

List<_PdfGrupoMueble> _pdfAgruparMuebles(List<Mueble> muebles) {
  final Map<String, List<Mueble>> grupos = {};
  for (final mueble in muebles) {
    final key = _pdfClaveGrupo(mueble);
    grupos.putIfAbsent(key, () => []).add(mueble);
  }
  final lista = grupos.values.map(_PdfGrupoMueble.new).toList();
  lista.sort((a, b) => a.nombre.compareTo(b.nombre));
  return lista;
}

List<_PdfMaterialAcumulado> _pdfAgruparMateriales(List<Mueble> muebles) {
  final Map<String, _PdfMaterialAcumulado> acumulado = {};

  for (final mueble in muebles) {
    final multiplicador = _pdfCantidadValida(mueble.cantidadEnProceso);
    for (final parte in mueble.partes) {
      for (final raw in parte.materiales) {
        final material = MaterialMueble.fromMap(raw);
        final key = _pdfClaveMaterial(material);
        final cantidadTotal = material.cantidad * multiplicador;

        final existente = acumulado[key];
        if (existente == null) {
          acumulado[key] = _PdfMaterialAcumulado(
            material: MaterialMueble(
              tipo: material.tipo,
              material: material.material,
              espesorMm: material.espesorMm,
              largoCm: material.largoCm,
              anchoCm: material.anchoCm,
              cantidad: 0,
            ),
            total: cantidadTotal,
            completadas: material.completado ? cantidadTotal : 0,
          );
        } else {
          existente.total += cantidadTotal;
          if (material.completado) {
            existente.completadas += cantidadTotal;
          }
        }
      }
    }
  }

  return acumulado.values.toList();
}

List<_PdfMaterialGrupo> _pdfAgruparMaterialesGlobal(
  List<_PdfMaterialAcumulado> materiales,
) {
  final Map<String, List<_PdfMaterialLinea>> porTitulo = {};
  final Map<String, double> areaPorTitulo = {};

  for (final material in materiales) {
    final base = material.material;
    final titulo = _pdfTituloMaterial(base);

    if (material.pendientes > 0) {
      porTitulo
          .putIfAbsent(titulo, () => [])
          .add(
            _PdfMaterialLinea(
              cantidad: material.pendientes,
              largoCm: base.largoCm,
              anchoCm: base.anchoCm,
              tipo: base.tipo,
              completado: false,
            ),
          );

      if (_pdfEsMaterialEnHoja(base.material)) {
        final areaPiezas = base.largoCm * base.anchoCm * material.pendientes;
        areaPorTitulo[titulo] = (areaPorTitulo[titulo] ?? 0) + areaPiezas;
      }
    }

    if (material.completadas > 0) {
      porTitulo
          .putIfAbsent(titulo, () => [])
          .add(
            _PdfMaterialLinea(
              cantidad: material.completadas,
              largoCm: base.largoCm,
              anchoCm: base.anchoCm,
              tipo: base.tipo,
              completado: true,
            ),
          );
    }
  }

  final grupos = porTitulo.entries.map((e) {
    final area = areaPorTitulo[e.key];
    return _PdfMaterialGrupo(
      titulo: e.key,
      items: e.value,
      hojas: _pdfCalcularHojas(area),
    );
  }).toList();

  for (final grupo in grupos) {
    grupo.items.sort((a, b) {
      final tipo = a.tipo.compareTo(b.tipo);
      if (tipo != 0) return tipo;
      final largo = a.largoCm.compareTo(b.largoCm);
      if (largo != 0) return largo;
      final ancho = a.anchoCm.compareTo(b.anchoCm);
      if (ancho != 0) return ancho;
      if (a.completado == b.completado) return 0;
      return a.completado ? 1 : -1;
    });
  }

  grupos.sort((a, b) {
    final aIsTiras = a.titulo.toLowerCase().startsWith('tiras de madera');
    final bIsTiras = b.titulo.toLowerCase().startsWith('tiras de madera');
    if (aIsTiras && !bIsTiras) return -1;
    if (!aIsTiras && bIsTiras) return 1;
    return a.titulo.compareTo(b.titulo);
  });

  return grupos;
}

List<_PdfMaterialGrupo> _pdfAgruparPuertasCajones(
  List<_PdfMaterialAcumulado> materiales,
) {
  if (materiales.isEmpty) return [];

  final Map<String, List<_PdfMaterialAcumulado>> porTitulo = {};

  for (final material in materiales) {
    final base = material.material;
    final baseTitulo = _pdfTituloMaterial(base);
    final titulo = base.material == null
        ? 'Puertas y/o cajones'
        : 'Puertas y/o cajones - $baseTitulo';
    porTitulo.putIfAbsent(titulo, () => []).add(material);
  }

  final grupos = porTitulo.entries.map((e) {
    final items = <_PdfMaterialLinea>[];
    double areaTotal = 0;

    for (final m in e.value) {
      final base = m.material;
      if (m.pendientes > 0) {
        items.add(
          _PdfMaterialLinea(
            cantidad: m.pendientes,
            largoCm: base.largoCm,
            anchoCm: base.anchoCm,
            tipo: base.tipo,
            completado: false,
          ),
        );
        areaTotal += base.largoCm * base.anchoCm * m.pendientes;
      }
      if (m.completadas > 0) {
        items.add(
          _PdfMaterialLinea(
            cantidad: m.completadas,
            largoCm: base.largoCm,
            anchoCm: base.anchoCm,
            tipo: base.tipo,
            completado: true,
          ),
        );
      }
    }

    items.sort((a, b) {
      final tipo = a.tipo.compareTo(b.tipo);
      if (tipo != 0) return tipo;
      final largo = a.largoCm.compareTo(b.largoCm);
      if (largo != 0) return largo;
      final ancho = a.anchoCm.compareTo(b.anchoCm);
      if (ancho != 0) return ancho;
      if (a.completado == b.completado) return 0;
      return a.completado ? 1 : -1;
    });

    return _PdfMaterialGrupo(
      titulo: e.key,
      items: items,
      hojas: _pdfCalcularHojas(areaTotal),
    );
  }).toList();

  grupos.sort((a, b) => a.titulo.compareTo(b.titulo));
  return grupos;
}

String _pdfTituloMaterial(MaterialMueble material) {
  if (material.material == null) return material.tipo;
  if (material.espesorMm == null) return material.material!;
  return '${material.material} ${_pdfFmt(material.espesorMm!)} mm';
}

String _pdfClaveGrupo(Mueble mueble) {
  return '${mueble.nombre}|'
      '${mueble.anchoCm.toStringAsFixed(2)}|'
      '${mueble.altoCm.toStringAsFixed(2)}|'
      '${mueble.fondoCm.toStringAsFixed(2)}';
}

String _pdfClaveMaterial(MaterialMueble material) {
  final materialNombre = material.material ?? '';
  final espesor = material.espesorMm?.toStringAsFixed(2) ?? '';
  final largo = material.largoCm.toStringAsFixed(2);
  final ancho = material.anchoCm.toStringAsFixed(2);
  return '${material.tipo}|$materialNombre|$espesor|$largo|$ancho';
}

int _pdfCantidadValida(int value) => value < 1 ? 1 : value;

const _pdfTiposPuertasCajones = {
  'Puertas grandes',
  'Puertas chicas',
  'Tapaderas de Cajones',
};

bool _pdfEsMaterialEnHoja(String? material) {
  if (material == null) return false;
  const permitidos = {'MDF', 'Okume', 'Pino', 'Caobilla'};
  return permitidos.contains(material);
}

int? _pdfCalcularHojas(double? areaTotalCm2) {
  if (areaTotalCm2 == null || areaTotalCm2 <= 0) return null;
  const areaHojaCm2 = 244 * 122;
  return (areaTotalCm2 / areaHojaCm2).ceil();
}

String _pdfFmt(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}
