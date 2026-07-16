import '../models/favorito.dart';
import 'cola_sincronizacion_dao.dart';
import 'database_helper.dart';

class FavoritoDao {
  final ColaSincronizacionDao _cola = ColaSincronizacionDao();

  Future<void> agregar(Favorito favorito) async {
    final db = await DatabaseHelper.database;
    await db.insert('favoritos', favorito.toMap());
    await _cola.encolar(
      tabla: 'favoritos',
      registroId: favorito.id,
      operacion: 'create',
      payload: favorito.toMap(),
    );
  }

  Future<void> quitar(String usuarioId, String negocioId) async {
    final db = await DatabaseHelper.database;
    // Necesitamos el id del favorito antes de borrarlo, para poder
    // encolar el delete (la nube identifica por id, no por el par usuario+negocio).
    final filas = await db.query(
      'favoritos',
      where: 'usuario_id = ? AND negocio_id = ?',
      whereArgs: [usuarioId, negocioId],
      limit: 1,
    );
    await db.delete(
      'favoritos',
      where: 'usuario_id = ? AND negocio_id = ?',
      whereArgs: [usuarioId, negocioId],
    );
    if (filas.isNotEmpty) {
      await _cola.encolar(
        tabla: 'favoritos',
        registroId: filas.first['id'] as String,
        operacion: 'delete',
        payload: {'usuario_id': usuarioId, 'negocio_id': negocioId},
      );
    }
  }

  Future<bool> esFavorito(String usuarioId, String negocioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query(
      'favoritos',
      where: 'usuario_id = ? AND negocio_id = ?',
      whereArgs: [usuarioId, negocioId],
      limit: 1,
    );
    return filas.isNotEmpty;
  }

  Future<List<Favorito>> obtenerPorUsuario(String usuarioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query(
      'favoritos',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'fecha DESC',
    );
    return filas.map((f) => Favorito.fromMap(f)).toList();
  }

  /// IDs de negocios favoritos, útil para cruzar con negocios_propios/cache
  /// y marcar `esFavorito` en el modelo Negocio al listar.
  Future<Set<String>> obtenerIdsFavoritos(String usuarioId) async {
    final favoritos = await obtenerPorUsuario(usuarioId);
    return favoritos.map((f) => f.negocioId).toSet();
  }
}
