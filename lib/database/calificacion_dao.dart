import 'package:sqflite/sqflite.dart';
import '../models/calificacion.dart';
import 'cola_sincronizacion_dao.dart';
import 'database_helper.dart';

class CalificacionDao {
  final ColaSincronizacionDao _cola = ColaSincronizacionDao();

  Future<void> insertar(Calificacion calificacion) async {
    final db = await DatabaseHelper.database;
    await db.insert('calificaciones', calificacion.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _cola.encolar(
      tabla: 'calificaciones',
      registroId: calificacion.id,
      operacion: 'upsert',
      payload: calificacion.toMap(),
    );
  }

  Future<Calificacion?> obtenerPorUsuario(String usuarioId, String negocioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query(
      'calificaciones',
      where: 'usuario_id = ? AND negocio_id = ?',
      whereArgs: [usuarioId, negocioId],
      limit: 1,
    );
    return filas.isNotEmpty ? Calificacion.fromMap(filas.first) : null;
  }

  Future<Map<String, dynamic>> obtenerEstadisticas(String negocioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.rawQuery('''
      SELECT COUNT(*) AS total, ROUND(AVG(calificacion), 1) AS promedio
      FROM calificaciones
      WHERE negocio_id = ?
    ''', [negocioId]);
    if (filas.isEmpty) return {'total': 0, 'promedio': 0.0};
    return {
      'total': filas.first['total'] as int? ?? 0,
      'promedio': (filas.first['promedio'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<List<Calificacion>> obtenerTodasPorNegocio(String negocioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query(
      'calificaciones',
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
      orderBy: 'fecha DESC',
    );
    return filas.map((f) => Calificacion.fromMap(f)).toList();
  }

  Future<void> eliminar(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('calificaciones', where: 'id = ?', whereArgs: [id]);
    await _cola.encolar(
      tabla: 'calificaciones',
      registroId: id,
      operacion: 'delete',
      payload: {'id': id},
    );
  }
}
