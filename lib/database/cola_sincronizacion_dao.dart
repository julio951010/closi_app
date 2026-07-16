import 'dart:convert';
import 'database_helper.dart';

/// Acceso a la cola de cambios locales pendientes de subir a la nube.
///
/// Cada vez que un DAO escribe algo que el usuario creó/modificó localmente
/// (un negocio propio, un favorito, una reseña...), además de escribir en su
/// tabla local, debe llamar a `encolar(...)` aquí. `SyncService` es quien
/// luego procesa esta cola cuando hay conexión.
class ColaSincronizacionDao {
  Future<void> encolar({
    required String tabla,
    required String registroId,
    required String operacion, // create | update | delete
    Map<String, dynamic>? payload,
  }) async {
    final db = await DatabaseHelper.database;
    await db.insert('cola_sincronizacion', {
      'tabla': tabla,
      'registro_id': registroId,
      'operacion': operacion,
      'payload': payload != null ? jsonEncode(payload) : null,
      'intentos': 0,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> obtenerPendientes({int maxIntentos = 5}) async {
    final db = await DatabaseHelper.database;
    return db.query(
      'cola_sincronizacion',
      where: 'intentos < ?',
      whereArgs: [maxIntentos],
      orderBy: 'fecha_creacion ASC',
    );
  }

  Future<void> marcarCompletado(int id) async {
    final db = await DatabaseHelper.database;
    await db.delete('cola_sincronizacion', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> registrarFallo(int id, String error) async {
    final db = await DatabaseHelper.database;
    await db.rawUpdate('''
      UPDATE cola_sincronizacion
      SET intentos = intentos + 1, ultimo_intento = ?, error = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), error, id]);
  }

  Future<int> contarPendientes() async {
    final db = await DatabaseHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM cola_sincronizacion');
    return (res.first['c'] as int?) ?? 0;
  }
}
