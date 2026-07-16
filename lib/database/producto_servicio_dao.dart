import '../models/producto_servicio.dart';
import 'cola_sincronizacion_dao.dart';
import 'database_helper.dart';

class ProductoServicioDao {
  final ColaSincronizacionDao _cola = ColaSincronizacionDao();

  Future<void> guardar(ProductoServicio item, {required bool esNuevo}) async {
    final db = await DatabaseHelper.database;
    final ahora = DateTime.now().toIso8601String();
    final data = item.toMap()
      ..['actualizado_en'] = ahora
      ..['estado_sync'] = 'pendiente';
    if (esNuevo) {
      data['creado_en'] = ahora;
      await db.insert('productos_servicios', data);
    } else {
      await db.update('productos_servicios', data, where: 'id = ?', whereArgs: [item.id]);
    }
    await _cola.encolar(
      tabla: 'productos_servicios',
      registroId: item.id,
      operacion: esNuevo ? 'create' : 'update',
      payload: data,
    );
  }

  Future<List<ProductoServicio>> obtenerPorNegocio(String negocioId) async {
    final db = await DatabaseHelper.database;
    final filas = await db.query(
      'productos_servicios',
      where: 'negocio_id = ?',
      whereArgs: [negocioId],
      orderBy: 'creado_en DESC',
    );
    return filas.map((f) => ProductoServicio.fromMap(f)).toList();
  }

  Future<void> eliminar(String id) async {
    final db = await DatabaseHelper.database;
    await db.delete('productos_servicios', where: 'id = ?', whereArgs: [id]);
    await _cola.encolar(
      tabla: 'productos_servicios',
      registroId: id,
      operacion: 'delete',
      payload: {'id': id},
    );
  }
}
