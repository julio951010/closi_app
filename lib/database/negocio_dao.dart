import 'package:sqflite/sqflite.dart';
import '../models/negocio.dart';
import 'cola_sincronizacion_dao.dart';
import 'database_helper.dart';

/// Acceso a datos para negocios, cubriendo las dos tablas locales:
/// - `negocios_propios`: administrados por el usuario (editable).
/// - `negocios_cache`: descargados para consulta offline (solo lectura, purgable).
class NegocioDao {
  final ColaSincronizacionDao _cola = ColaSincronizacionDao();

  // ---------------- NEGOCIOS PROPIOS ----------------

  Future<void> guardarPropio(Negocio negocio, {required bool esNuevo}) async {
    final db = await DatabaseHelper.database;
    final ahora = DateTime.now().toIso8601String();
    final data = negocio.toMapPropio()
      ..['actualizado_en'] = ahora
      ..['estado_sync'] = 'pendiente';
    if (esNuevo) {
      data['creado_en'] = ahora;
      await db.insert('negocios_propios', data);
    } else {
      await db.update('negocios_propios', data,
          where: 'id = ?', whereArgs: [negocio.id]);
    }
    await _cola.encolar(
      tabla: 'negocios_propios',
      registroId: negocio.id,
      operacion: esNuevo ? 'create' : 'update',
      payload: data,
    );
  }

  Future<List<Negocio>> obtenerPropios(String usuarioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query('negocios_propios', orderBy: 'creado_en DESC');
    return filas.map((f) => Negocio.fromMapPropio(f)).toList();
  }

  Future<List<Negocio>> obtenerPropiosPorIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await DatabaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final filas = await db.query(
      'negocios_propios',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return filas.map((f) => Negocio.fromMapPropio(f)).toList();
  }

  Future<void> eliminarPropio(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('negocios_propios', where: 'id = ?', whereArgs: [id]);
    await _cola.encolar(tabla: 'negocios_propios', registroId: id, operacion: 'delete');
  }

  // ---------------- NEGOCIOS CACHE ----------------

  /// Inserta o actualiza un lote de negocios en caché (tras una descarga por
  /// zona/bounding box). Usa `ConflictAlgorithm.replace` porque la caché es
  /// desechable y se refresca completa por registro.
  Future<void> guardarLoteCache(List<Negocio> negocios) async {
    final db = await DatabaseHelper.database;
    final batch = db.batch();
    final ahora = DateTime.now().toIso8601String();
    for (final n in negocios) {
      final data = n.toMapCache()..['ultima_sincronizacion'] = ahora;
      // Preserva ultimo_acceso si ya existía (no lo pisamos en refresh)
      batch.insert('negocios_cache', data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Negocio>> obtenerCachePorZona({
    required double latMin,
    required double latMax,
    required double lonMin,
    required double lonMax,
  }) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query(
      'negocios_cache',
      where: 'lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?',
      whereArgs: [latMin, latMax, lonMin, lonMax],
    );
    return filas.map((f) => Negocio.fromMapCache(f)).toList();
  }

  /// Todos los negocios en caché, sin filtrar por zona.
  Future<List<Negocio>> obtenerTodosCache() async {
    final db = await DatabaseHelper.database;
    final filas = await db.query('negocios_cache', orderBy: 'nombre ASC');
    return filas.map((f) => Negocio.fromMapCache(f)).toList();
  }

  Future<List<Negocio>> obtenerCachePorIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await DatabaseHelper.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final filas = await db.query(
      'negocios_cache',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return filas.map((f) => Negocio.fromMapCache(f)).toList();
  }

  /// Marca un negocio de caché como accedido recientemente (para LRU).
  Future<void> registrarAcceso(String negocioId) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'negocios_cache',
      {'ultimo_acceso': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [negocioId],
    );
  }

  Future<int> contarCache() async {
    final db = await DatabaseHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM negocios_cache');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Obtiene un negocio por ID desde negocios_propios o negocios_cache.
  Future<Negocio?> obtenerPorId(String id) async {
    final db = await DatabaseHelper.database;
    final filasPropio = await db.query('negocios_propios', where: 'id = ?', whereArgs: [id]);
    if (filasPropio.isNotEmpty) return Negocio.fromMapPropio(filasPropio.first);
    final filasCache = await db.query('negocios_cache', where: 'id = ?', whereArgs: [id]);
    if (filasCache.isNotEmpty) return Negocio.fromMapCache(filasCache.first);
    return null;
  }

  /// Purga los registros menos usados recientemente cuando se supera el
  /// límite configurado en `config_app` (clave `limite_negocios_cache`).
  Future<void> purgarSiExcedeLimite(int limite) async {
    final db = await DatabaseHelper.database;
    final total = await contarCache();
    if (total <= limite) return;

    final exceso = total - limite;
    // Borra primero los que nunca se han accedido (ultimo_acceso NULL),
    // luego los más antiguos por ultimo_acceso.
    await db.rawDelete('''
      DELETE FROM negocios_cache WHERE id IN (
        SELECT id FROM negocios_cache
        ORDER BY ultimo_acceso IS NOT NULL, ultimo_acceso ASC
        LIMIT ?
      )
    ''', [exceso]);
  }

  Future<void> actualizarCalificacionCache(String negocioId, double promedio, int total) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'negocios_cache',
      {'calificacion_promedio': promedio, 'total_resenas': total},
      where: 'id = ?',
      whereArgs: [negocioId],
    );
  }

  Future<void> limpiarCache() async {
    final db = await DatabaseHelper.database;
    await db.delete('negocios_cache');
  }
}
