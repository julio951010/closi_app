import 'package:sqflite/sqflite.dart';
import '../models/opinion.dart';
import 'cola_sincronizacion_dao.dart';
import 'database_helper.dart';

class OpinionDao {
  final ColaSincronizacionDao _cola = ColaSincronizacionDao();

  Future<void> insertar(Opinion opinion) async {
    final db = await DatabaseHelper.database;
    final nombre = opinion.nombreUsuario ?? await _obtenerNombreUsuario(opinion.usuarioId);
    final data = opinion.copyWith(nombreUsuario: nombre).toMap();
    await db.insert('opiniones', data, conflictAlgorithm: ConflictAlgorithm.replace);
    await _cola.encolar(
      tabla: 'opiniones',
      registroId: opinion.id,
      operacion: 'upsert',
      payload: data,
    );
  }

  Future<String?> _obtenerNombreUsuario(String usuarioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query('usuario', columns: ['nombre'], where: 'id = ?', whereArgs: [usuarioId], limit: 1);
    return filas.isNotEmpty ? filas.first['nombre'] as String? : null;
  }

  Future<List<Opinion>> obtenerPorNegocio(String negocioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.rawQuery('''
      SELECT o.*, u.nombre AS nombre_usuario
      FROM opiniones o
      LEFT JOIN usuario u ON u.id = o.usuario_id
      WHERE o.negocio_id = ?
      ORDER BY o.fecha DESC
    ''', [negocioId]);
    return filas.map((f) => Opinion.fromMap(f)).toList();
  }

  Future<Opinion?> obtenerPorId(String id) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query('opiniones', where: 'id = ?', whereArgs: [id], limit: 1);
    return filas.isNotEmpty ? Opinion.fromMap(filas.first) : null;
  }

  Future<void> eliminar(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('opiniones', where: 'id = ?', whereArgs: [id]);
    await _cola.encolar(
      tabla: 'opiniones',
      registroId: id,
      operacion: 'delete',
      payload: {'id': id},
    );
  }
}
