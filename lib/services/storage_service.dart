import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mueble.dart';

class StorageService {
  static const _key = 'muebles_guardados';
  static const _inventarioKey = 'inventario_hojas';
  static const _historialKey = 'historial_semanal';
  static const _historialMueblesKey = 'historial_muebles';
  static const _historialCalculadoraKey = 'historial_calculadora';
  static const _puertasCajonesKey = 'calculadora_puertas_cajones';
  static const _backupVersion = 1;

  /// GUARDAR
  static Future<void> guardarMuebles(List<Mueble> muebles) async {
    final prefs = await SharedPreferences.getInstance();
    final data = muebles.map((m) => m.toMap()).toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// CARGAR
  static Future<List<Mueble>> cargarMuebles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);

    if (jsonString == null) return [];

    final List decoded = jsonDecode(jsonString);
    final List<Map<String, dynamic>> maps = [];
    var requiereMigracion = false;

    for (var i = 0; i < decoded.length; i++) {
      final raw = Map<String, dynamic>.from(decoded[i] as Map);
      if (raw['id'] == null) {
        raw['id'] = _generarId(i);
        requiereMigracion = true;
      }
      if (raw['cantidadEnProceso'] == null) {
        raw['cantidadEnProceso'] = 1;
        requiereMigracion = true;
      }
      maps.add(raw);
    }

    final muebles = maps.map((e) => Mueble.fromMap(e)).toList();

    if (requiereMigracion) {
      await prefs.setString(_key, jsonEncode(maps));
    }

    return muebles;
  }

  static Future<void> guardarMuebleIndividual(Mueble mueble) async {
    final muebles = await cargarMuebles();

    final index = muebles.indexWhere((m) => m.id == mueble.id);

    if (index != -1) {
      muebles[index] = mueble;
    } else {
      muebles.add(mueble);
    }

    await guardarMuebles(muebles);
  }

  static String _generarId(int seed) {
    return '${DateTime.now().microsecondsSinceEpoch}_$seed';
  }

  /// INVENTARIO DE HOJAS
  static Future<Map<String, int>> cargarInventarioHojas() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_inventarioKey);
    if (jsonString == null) return {};

    final Map<String, dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  static Future<void> guardarInventarioHojas(
    Map<String, int> inventario,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inventarioKey, jsonEncode(inventario));
  }

  static Future<void> sumarInventario(Map<String, int> add) async {
    final inventario = await cargarInventarioHojas();
    add.forEach((k, v) {
      inventario[k] = (inventario[k] ?? 0) + v;
    });
    await guardarInventarioHojas(inventario);
  }

  static Future<void> restarInventario(Map<String, int> consumo) async {
    final inventario = await cargarInventarioHojas();
    consumo.forEach((k, v) {
      final actual = inventario[k] ?? 0;
      final nuevo = actual - v;
      inventario[k] = nuevo < 0 ? 0 : nuevo;
    });
    await guardarInventarioHojas(inventario);
  }

  /// HISTORIAL SEMANAL
  static Future<Map<String, Map<String, int>>> cargarHistorialSemanal() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historialKey);
    if (jsonString == null) return {};

    final Map<String, dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((week, data) {
      final map = Map<String, dynamic>.from(data as Map);
      return MapEntry(week, map.map((k, v) => MapEntry(k, (v as num).toInt())));
    });
  }

  static Future<void> guardarHistorialSemanal(
    Map<String, Map<String, int>> historial,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historialKey, jsonEncode(historial));
  }

  static Future<void> agregarConsumoSemanal(Map<String, int> consumo) async {
    if (consumo.isEmpty) return;
    final historial = await cargarHistorialSemanal();
    final weekKey = _weekKey(DateTime.now());
    final actual = Map<String, int>.from(historial[weekKey] ?? {});

    consumo.forEach((k, v) {
      actual[k] = (actual[k] ?? 0) + v;
    });

    historial[weekKey] = actual;
    await guardarHistorialSemanal(historial);
  }

  static Future<Map<String, Map<String, int>>> cargarHistorialMuebles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historialMueblesKey);
    if (jsonString == null) return {};

    final Map<String, dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((week, data) {
      final map = Map<String, dynamic>.from(data as Map);
      return MapEntry(week, map.map((k, v) => MapEntry(k, (v as num).toInt())));
    });
  }

  static Future<void> guardarHistorialMuebles(
    Map<String, Map<String, int>> historial,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historialMueblesKey, jsonEncode(historial));
  }

  static Future<void> agregarMueblesSemanal(Map<String, int> muebles) async {
    if (muebles.isEmpty) return;
    final historial = await cargarHistorialMuebles();
    final weekKey = _weekKey(DateTime.now());
    final actual = Map<String, int>.from(historial[weekKey] ?? {});

    muebles.forEach((k, v) {
      actual[k] = (actual[k] ?? 0) + v;
    });

    historial[weekKey] = actual;
    await guardarHistorialMuebles(historial);
  }

  static Future<void> borrarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historialKey);
    await prefs.remove(_historialMueblesKey);
  }

  /// HISTORIAL CALCULADORA
  static Future<List<Map<String, String>>> cargarHistorialCalculadora() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historialCalculadoraKey);
    if (jsonString == null) return [];

    final List decoded = jsonDecode(jsonString);
    return decoded
        .map((e) {
          final map = Map<String, dynamic>.from(e as Map);
          return {
            'expresion': map['expresion']?.toString() ?? '',
            'resultado': map['resultado']?.toString() ?? '',
          };
        })
        .toList()
        .cast<Map<String, String>>();
  }

  static Future<void> guardarHistorialCalculadora(
    List<Map<String, String>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historialCalculadoraKey, jsonEncode(items));
  }

  /// CALCULADORA PUERTAS / CAJONES
  static Future<Map<String, dynamic>?> cargarEstadoPuertasCajones() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_puertasCajonesKey);
    if (jsonString == null) return null;
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) return null;
    return decoded;
  }

  static Future<void> guardarEstadoPuertasCajones(
    Map<String, dynamic> estado,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_puertasCajonesKey, jsonEncode(estado));
  }

  static Future<void> borrarEstadoPuertasCajones() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_puertasCajonesKey);
  }

  /// BACKUP / RESTORE
  static Future<Map<String, dynamic>> exportarBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'schemaVersion': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      _key: prefs.getString(_key),
      _inventarioKey: prefs.getString(_inventarioKey),
      _historialKey: prefs.getString(_historialKey),
      _historialMueblesKey: prefs.getString(_historialMueblesKey),
      _historialCalculadoraKey: prefs.getString(_historialCalculadoraKey),
      _puertasCajonesKey: prefs.getString(_puertasCajonesKey),
    };
  }

  static Future<void> importarBackup(Map<String, dynamic> backup) async {
    final prefs = await SharedPreferences.getInstance();
    await _setOrRemoveString(prefs, _key, backup[_key]);
    await _setOrRemoveString(prefs, _inventarioKey, backup[_inventarioKey]);
    await _setOrRemoveString(prefs, _historialKey, backup[_historialKey]);
    await _setOrRemoveString(
      prefs,
      _historialMueblesKey,
      backup[_historialMueblesKey],
    );
    await _setOrRemoveString(
      prefs,
      _historialCalculadoraKey,
      backup[_historialCalculadoraKey],
    );
    await _setOrRemoveString(
      prefs,
      _puertasCajonesKey,
      backup[_puertasCajonesKey],
    );
  }

  static Future<void> _setOrRemoveString(
    SharedPreferences prefs,
    String key,
    dynamic raw,
  ) async {
    if (raw == null) {
      await prefs.remove(key);
      return;
    }

    if (raw is String) {
      await prefs.setString(key, raw);
      return;
    }

    await prefs.setString(key, jsonEncode(raw));
  }

  static String _weekKey(DateTime date) {
    final inicio = _inicioSemana(date);
    return _formatDate(inicio);
  }

  static DateTime _inicioSemana(DateTime date) {
    final diasARestar = date.weekday - DateTime.monday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: diasARestar));
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
