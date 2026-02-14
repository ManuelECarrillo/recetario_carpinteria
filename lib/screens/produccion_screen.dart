import 'package:flutter/material.dart';
import '../models/mueble.dart';
import '../models/material_mueble.dart';
import '../services/storage_service.dart';
import 'cortes_puertas_screen.dart';
import 'en_proceso_screen.dart';
import 'historial_screen.dart';

class ProduccionScreen extends StatefulWidget {
  const ProduccionScreen({super.key});

  @override
  State<ProduccionScreen> createState() => _ProduccionScreenState();
}

class _ProduccionScreenState extends State<ProduccionScreen> {
  bool _cargando = true;
  List<Mueble> _muebles = [];
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final muebles = await StorageService.cargarMuebles();
    if (!mounted) return;
    setState(() {
      _muebles = muebles;
      _cargando = false;
      _refreshToken++;
    });
  }

  Future<void> _confirmarFinalizarGrupo(_GrupoMueble grupo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finalizar producción'),
        content: Text(
          '¿Confirmas finalizar ${grupo.cantidad} mueble(s) de '
          '"${grupo.nombre}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final consumo = _calcularConsumoHojas(grupo.muebles);
    final mueblesFinalizados = _calcularMueblesFinalizados(grupo.muebles);
    await StorageService.agregarConsumoSemanal(consumo);
    await StorageService.agregarMueblesSemanal(mueblesFinalizados);
    await StorageService.restarInventario(consumo);

    setState(() {
      for (final mueble in grupo.muebles) {
        mueble.enProceso = false;
        mueble.cantidadEnProceso = 1;
        for (final parte in mueble.partes) {
          for (final material in parte.materiales) {
            material['completado'] = false;
          }
        }
      }
    });

    await StorageService.guardarMuebles(_muebles);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Producción finalizada')));
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final enProceso = _muebles.where((m) => m.enProceso).toList();
    final grupos = _agruparMuebles(enProceso);
    final materialesAgrupados = _agruparMateriales(enProceso);
    final materialesPuertas = materialesAgrupados
        .where((m) => _tiposPuertasCajones.contains(m.material.tipo))
        .toList();
    final materialesGenerales = materialesAgrupados
        .where((m) => !_tiposPuertasCajones.contains(m.material.tipo))
        .toList();
    final gruposPuertas = _agruparPuertasCajones(materialesPuertas);
    final materiales = _agruparMaterialesGlobal(materialesGenerales);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B3A2F),
        title: const Text('Produccion del dia'),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Historial e inventario',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistorialScreen()),
              );
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (!isWide) {
                  return _buildVerticalBody(
                    context,
                    grupos,
                    materiales,
                    gruposPuertas,
                  );
                }
                return _buildWideBody(
                  context,
                  grupos,
                  materiales,
                  gruposPuertas,
                );
              },
            ),
    );
  }

  Widget _buildVerticalBody(
    BuildContext context,
    List<_GrupoMueble> grupos,
    List<_MaterialGrupo> materiales,
    List<_MaterialGrupo> gruposPuertas,
  ) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        key: ValueKey(_refreshToken),
        padding: const EdgeInsets.all(16),
        children: [
          _sectionMuebles(context, grupos),
          const SizedBox(height: 24),
          _sectionMateriales(context, materiales),
          const SizedBox(height: 32),
          _separadorFuerte(),
          const SizedBox(height: 20),
          _sectionPuertas(context, gruposPuertas),
        ],
      ),
    );
  }

  Widget _buildWideBody(
    BuildContext context,
    List<_GrupoMueble> grupos,
    List<_MaterialGrupo> materiales,
    List<_MaterialGrupo> gruposPuertas,
  ) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: ListView(
              key: ValueKey('muebles-$_refreshToken'),
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
              children: [_sectionMuebles(context, grupos)],
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              key: ValueKey('materiales-$_refreshToken'),
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              children: [
                _sectionMateriales(context, materiales),
                const SizedBox(height: 32),
                _separadorFuerte(),
                const SizedBox(height: 20),
                _sectionPuertas(context, gruposPuertas),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _separadorFuerte() {
    return Container(
      height: 8,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _sectionMuebles(BuildContext context, List<_GrupoMueble> grupos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Muebles en proceso',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (grupos.isEmpty)
          Text(
            'No hay muebles en proceso.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...grupos.map((g) => _cardResumenMueble(context, g)),
      ],
    );
  }

  Widget _sectionMateriales(
    BuildContext context,
    List<_MaterialGrupo> materiales,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Materiales a cortar',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (materiales.isEmpty)
          Text(
            'No hay materiales pendientes.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...materiales.map(
            (g) => _cardMaterial(
              key: ValueKey('${g.titulo}-${g.hojas}-${g.items.length}'),
              titulo: g.titulo,
              items: g.items,
              hojas: g.hojas,
              aprovechamiento: g.aprovechamiento,
              onCortes: g.hojas == null || g.materiales.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CortesHojasScreen(
                            materiales: g.materiales,
                            titulo: 'Cortes ${g.titulo}',
                          ),
                        ),
                      );
                    },
            ),
          ),
      ],
    );
  }

  Widget _sectionPuertas(
    BuildContext context,
    List<_MaterialGrupo> gruposPuertas,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Puertas y/o cajones (15 mm)',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (gruposPuertas.isEmpty)
          Text(
            'No hay puertas ni cajones pendientes.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...gruposPuertas.map(
            (g) => _cardMaterial(
              key: ValueKey('${g.titulo}-${g.hojas}-${g.items.length}'),
              titulo: g.titulo,
              items: g.items,
              hojas: g.hojas,
              aprovechamiento: g.aprovechamiento,
              onCortes: g.hojas == null || g.materiales.isEmpty
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CortesHojasScreen(
                            materiales: g.materiales,
                            titulo: 'Cortes ${g.titulo}',
                          ),
                        ),
                      );
                    },
            ),
          ),
      ],
    );
  }

  /// =========================
  /// CARD RESUMEN MUEBLE
  /// =========================
  Widget _cardResumenMueble(BuildContext context, _GrupoMueble grupo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: const Icon(Icons.chair_alt),
        title: Text(
          grupo.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(
              context,
            ).style.copyWith(color: Colors.black87),
            children: [
              const TextSpan(text: 'Medidas: '),
              TextSpan(
                text: grupo.medidas,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'x ${grupo.cantidad}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _confirmarFinalizarGrupo(grupo),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'Finalizar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B3A2F),
                  ),
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          if (grupo.muebles.length == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EnProcesoScreen(mueble: grupo.muebles.first),
              ),
            ).then((_) => _cargar());
            return;
          }

          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Text(
                      'Selecciona un mueble',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...grupo.muebles.map(
                      (m) => ListTile(
                        leading: const Icon(Icons.playlist_add_check),
                        title: Text(m.nombre),
                        subtitle: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(
                              context,
                            ).style.copyWith(color: Colors.black87),
                            children: [
                              const TextSpan(text: 'Medidas: '),
                              TextSpan(
                                text:
                                    '${_fmt(m.anchoCm)} x ${_fmt(m.altoCm)} cm',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Text('x ${m.cantidadEnProceso}'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EnProcesoScreen(mueble: m),
                            ),
                          ).then((_) => _cargar());
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// =========================
  /// CARD MATERIAL
  /// =========================
  Widget _cardMaterial({
    Key? key,
    required String titulo,
    required List<_MaterialLinea> items,
    required int? hojas,
    required double? aprovechamiento,
    required VoidCallback? onCortes,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (hojas != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2E7D32,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$hojas hojas',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(),
            if (onCortes != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onCortes,
                  icon: const Icon(Icons.grid_view),
                  label: const Text('Ver cortes'),
                ),
              ),
            ...items.map((item) {
              final style = TextStyle(
                fontSize: 16,
                color: item.completado ? Colors.grey.shade600 : Colors.black,
                decoration: item.completado ? TextDecoration.lineThrough : null,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: RichText(
                  text: TextSpan(
                    style: style,
                    children: [
                      TextSpan(
                        text:
                            '- ${item.cantidad} ${item.cantidad == 1 ? 'pieza' : 'piezas'} - ',
                      ),
                      TextSpan(
                        text:
                            '${_fmt(item.largoCm)} x ${_fmt(item.anchoCm)} cm',
                        style: style.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (item.tipo.isNotEmpty)
                        TextSpan(text: ' (${item.tipo})'),
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

class _GrupoMueble {
  final List<Mueble> muebles;
  final String nombre;
  final double anchoCm;
  final double altoCm;
  final double fondoCm;
  final int cantidad;

  _GrupoMueble(this.muebles)
    : nombre = muebles.first.nombre,
      anchoCm = muebles.first.anchoCm,
      altoCm = muebles.first.altoCm,
      fondoCm = muebles.first.fondoCm,
      cantidad = muebles.fold<int>(
        0,
        (sum, m) => sum + _cantidadValida(m.cantidadEnProceso),
      );

  String get medidas =>
      '${_fmt(anchoCm)} x ${_fmt(altoCm)} x ${_fmt(fondoCm)} cm';
}

class _MaterialGrupo {
  final String titulo;
  final List<_MaterialLinea> items;
  final int? hojas;
  final double? aprovechamiento;
  final List<MaterialMueble> materiales;

  _MaterialGrupo({
    required this.titulo,
    required this.items,
    required this.hojas,
    required this.aprovechamiento,
    required this.materiales,
  });
}

class _MaterialLinea {
  final int cantidad;
  final double largoCm;
  final double anchoCm;
  final String tipo;
  final bool completado;

  _MaterialLinea({
    required this.cantidad,
    required this.largoCm,
    required this.anchoCm,
    required this.tipo,
    required this.completado,
  });
}

class _MaterialAcumulado {
  final MaterialMueble material;
  int total;
  int completadas;

  _MaterialAcumulado({
    required this.material,
    required this.total,
    required this.completadas,
  });

  int get pendientes => total - completadas;
  bool get completado => pendientes <= 0;
}

List<_GrupoMueble> _agruparMuebles(List<Mueble> muebles) {
  final Map<String, List<Mueble>> grupos = {};
  for (final mueble in muebles) {
    final key = _claveGrupo(mueble);
    grupos.putIfAbsent(key, () => []).add(mueble);
  }

  final lista = grupos.values.map(_GrupoMueble.new).toList();
  lista.sort((a, b) => a.nombre.compareTo(b.nombre));
  return lista;
}

List<_MaterialGrupo> _agruparMaterialesGlobal(
  List<_MaterialAcumulado> materiales,
) {
  final Map<String, List<_MaterialLinea>> porTitulo = {};
  final Map<String, double> areaPorTitulo = {};
  final Map<String, List<MaterialMueble>> materialesPorTitulo = {};

  for (final material in materiales) {
    final base = material.material;
    final titulo = _tituloMaterial(base);

    if (material.pendientes > 0) {
      porTitulo
          .putIfAbsent(titulo, () => [])
          .add(
            _MaterialLinea(
              cantidad: material.pendientes,
              largoCm: base.largoCm,
              anchoCm: base.anchoCm,
              tipo: base.tipo,
              completado: false,
            ),
          );

      if (_esMaterialEnHoja(base.material)) {
        final areaPiezas = base.largoCm * base.anchoCm * material.pendientes;
        areaPorTitulo[titulo] = (areaPorTitulo[titulo] ?? 0) + areaPiezas;
      }

      materialesPorTitulo
          .putIfAbsent(titulo, () => [])
          .add(
            MaterialMueble(
              tipo: base.tipo,
              material: base.material,
              espesorMm: base.espesorMm,
              largoCm: base.largoCm,
              anchoCm: base.anchoCm,
              cantidad: material.pendientes,
            ),
          );
    }

    if (material.completadas > 0) {
      porTitulo
          .putIfAbsent(titulo, () => [])
          .add(
            _MaterialLinea(
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
    final hojas = _calcularHojas(area);
    final aprovechamiento = _calcularAprovechamiento(area, hojas);
    return _MaterialGrupo(
      titulo: e.key,
      items: e.value,
      hojas: hojas,
      aprovechamiento: aprovechamiento,
      materiales: materialesPorTitulo[e.key] ?? [],
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

List<_MaterialGrupo> _agruparPuertasCajones(
  List<_MaterialAcumulado> materiales,
) {
  if (materiales.isEmpty) return [];

  final Map<String, List<_MaterialAcumulado>> porTitulo = {};

  for (final material in materiales) {
    final base = material.material;
    final baseTitulo = _tituloMaterial(base);
    final titulo = base.material == null
        ? 'Puertas y/o cajones'
        : 'Puertas y/o cajones - $baseTitulo';
    porTitulo.putIfAbsent(titulo, () => []).add(material);
  }

  final grupos = porTitulo.entries.map((e) {
    final items = <_MaterialLinea>[];
    final materialesPendientes = <MaterialMueble>[];

    for (final m in e.value) {
      final base = m.material;
      if (m.pendientes > 0) {
        items.add(
          _MaterialLinea(
            cantidad: m.pendientes,
            largoCm: base.largoCm,
            anchoCm: base.anchoCm,
            tipo: base.tipo,
            completado: false,
          ),
        );
        materialesPendientes.add(
          MaterialMueble(
            tipo: base.tipo,
            material: base.material,
            espesorMm: base.espesorMm,
            largoCm: base.largoCm,
            anchoCm: base.anchoCm,
            cantidad: m.pendientes,
          ),
        );
      }
      if (m.completadas > 0) {
        items.add(
          _MaterialLinea(
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

    final areaTotal = materialesPendientes.fold<double>(
      0,
      (sum, m) => sum + (m.largoCm * m.anchoCm * m.cantidad),
    );
    final hojas = _calcularHojas(areaTotal);
    final aprovechamiento = _calcularAprovechamiento(areaTotal, hojas);

    return _MaterialGrupo(
      titulo: e.key,
      items: items,
      hojas: hojas,
      aprovechamiento: aprovechamiento,
      materiales: materialesPendientes,
    );
  }).toList();

  grupos.sort((a, b) => a.titulo.compareTo(b.titulo));
  return grupos;
}

List<_MaterialAcumulado> _agruparMateriales(List<Mueble> muebles) {
  final Map<String, _MaterialAcumulado> acumulado = {};

  for (final mueble in muebles) {
    final multiplicador = _cantidadValida(mueble.cantidadEnProceso);
    for (final parte in mueble.partes) {
      for (final raw in parte.materiales) {
        final material = MaterialMueble.fromMap(raw);
        final key = _claveMaterial(material);
        final cantidadTotal = material.cantidad * multiplicador;

        final existente = acumulado[key];
        if (existente == null) {
          acumulado[key] = _MaterialAcumulado(
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

Map<String, int> _calcularConsumoHojas(List<Mueble> muebles) {
  final Map<String, double> areaPorTitulo = {};

  for (final mueble in muebles) {
    final multiplicador = _cantidadValida(mueble.cantidadEnProceso);
    for (final parte in mueble.partes) {
      for (final raw in parte.materiales) {
        final material = MaterialMueble.fromMap(raw);
        if (!_esMaterialEnHoja(material.material)) continue;

        final area =
            material.largoCm *
            material.anchoCm *
            material.cantidad *
            multiplicador;
        final titulo = _tituloMaterial(material);
        areaPorTitulo[titulo] = (areaPorTitulo[titulo] ?? 0) + area;
      }
    }
  }

  final Map<String, int> consumo = {};
  areaPorTitulo.forEach((titulo, area) {
    final hojas = _calcularHojas(area);
    if (hojas != null && hojas > 0) {
      consumo[titulo] = hojas;
    }
  });
  return consumo;
}

Map<String, int> _calcularMueblesFinalizados(List<Mueble> muebles) {
  final Map<String, int> resultado = {};
  for (final mueble in muebles) {
    final cantidad = _cantidadValida(mueble.cantidadEnProceso);
    final key = _muebleKey(mueble);
    resultado[key] = (resultado[key] ?? 0) + cantidad;
  }
  return resultado;
}

String _muebleKey(Mueble mueble) {
  final medidas =
      '${_fmt(mueble.anchoCm)}x${_fmt(mueble.altoCm)}x${_fmt(mueble.fondoCm)}';
  return '${mueble.nombre}|$medidas';
}

String _tituloMaterial(MaterialMueble material) {
  if (material.material == null) {
    return material.tipo;
  }
  if (material.espesorMm == null) {
    return material.material!;
  }
  return '${material.material} ${_fmt(material.espesorMm!)} mm';
}

String _claveGrupo(Mueble mueble) {
  return '${mueble.nombre}|'
      '${_fixed(mueble.anchoCm)}|'
      '${_fixed(mueble.altoCm)}|'
      '${_fixed(mueble.fondoCm)}';
}

String _claveMaterial(MaterialMueble material) {
  final materialNombre = material.material ?? '';
  final espesor = material.espesorMm?.toStringAsFixed(2) ?? '';
  final largo = _fixed(material.largoCm);
  final ancho = _fixed(material.anchoCm);
  return '${material.tipo}|$materialNombre|$espesor|$largo|$ancho';
}

String _fixed(double value) => value.toStringAsFixed(2);

String _fmt(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}

int _cantidadValida(int value) => value < 1 ? 1 : value;

const _tiposPuertasCajones = {
  'Puertas grandes',
  'Puertas chicas',
  'Tapaderas de Cajones',
};

bool _esMaterialEnHoja(String? material) {
  if (material == null) return false;
  const permitidos = {'MDF', 'Okume', 'Pino', 'Caobilla'};
  return permitidos.contains(material);
}

int? _calcularHojas(double? areaTotalCm2) {
  if (areaTotalCm2 == null || areaTotalCm2 <= 0) return null;
  const areaHojaCm2 = 244 * 122;
  return (areaTotalCm2 / areaHojaCm2).ceil();
}

double? _calcularAprovechamiento(double? areaTotalCm2, int? hojas) {
  if (areaTotalCm2 == null || areaTotalCm2 <= 0) return null;
  if (hojas == null || hojas <= 0) return null;
  const areaHojaCm2 = 244 * 122;
  final areaTotalHojas = hojas * areaHojaCm2;
  return (areaTotalCm2 / areaTotalHojas) * 100;
}
