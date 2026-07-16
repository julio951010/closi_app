import '../models/perfil.dart';
import '../models/usuario.dart';
import '../repositories/usuario_repository.dart';

/// Servicio singleton que sostiene la sesión del usuario actual en memoria.
class SesionService {
  SesionService._();

  static final UsuarioRepository _repo = UsuarioRepository();

  static String _usuarioId = '';
  static Usuario _usuario = Usuario.invitado;

  static String get usuarioId => _usuarioId;
  static Usuario get usuario => _usuario;

  static bool get inicializada => _usuarioId.isNotEmpty;

  static Future<void> inicializar() async {
    final perfil = await _repo.obtenerPerfilActual();
    if (perfil != null) {
      _usuarioId = perfil.id;
      _usuario = _repo.perfilAUsuario(perfil);
    }
  }

  static void iniciarSesionLocal(Perfil perfil) {
    _usuarioId = perfil.id;
    _usuario = _repo.perfilAUsuario(perfil);
  }

  static Future<void> guardar(Perfil perfil) async {
    await _repo.guardarSesion(perfil);
    _usuarioId = perfil.id;
    _usuario = _repo.perfilAUsuario(perfil);
  }

  static Future<void> cerrarSesion() async {
    await _repo.cerrarSesion();
    _usuarioId = '';
    _usuario = Usuario.invitado;
  }
}
