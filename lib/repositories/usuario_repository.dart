import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/perfil.dart';
import '../models/usuario.dart';

class UsuarioRepository {
  Future<Perfil?> obtenerPerfilActual() async {
    final db = await DatabaseHelper.database;
    final filas = await db.query('usuario', where: 'token_sesion IS NOT NULL', limit: 1);
    if (filas.isEmpty) return null;
    return Perfil.fromMap(filas.first);
  }

  Future<void> guardarSesion(Perfil perfil) async {
    final db = await DatabaseHelper.database;
    await db.delete('usuario');
    try {
      await db.execute('ALTER TABLE usuario ADD COLUMN foto_url TEXT');
    } catch (_) {}
    final conToken = perfil.copyWith(tokenSesion: const Uuid().v4());
    await db.insert('usuario', conToken.toMap());
  }

  Future<void> cerrarSesion() async {
    final db = await DatabaseHelper.database;
    await db.delete('usuario');
  }

  Usuario perfilAUsuario(Perfil perfil) {
    return Usuario(
      id: perfil.id,
      nombre: perfil.nombre,
      email: perfil.email,
      telefono: perfil.telefono,
      fotoUrl: perfil.fotoUrl,
      rol: perfil.rol,
      estaLogueado: true,
    );
  }
}
