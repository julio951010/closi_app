/// Registro persistido del usuario en la base de datos local (tabla `usuario`).
///
/// Es el modelo de persistencia; `Usuario` (models/usuario.dart) sigue siendo
/// el modelo liviano usado para mostrar datos en la UI. `UsuarioRepository`
/// hace de puente entre ambos.
class Perfil {
  final String id;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? fotoUrl;
  final String? passwordHash;
  final String rol;
  final String? tokenSesion;
  final DateTime? fechaRegistro;
  final DateTime? ultimaSincronizacion;

  Perfil({
    required this.id,
    required this.nombre,
    this.email,
    this.telefono,
    this.fotoUrl,
    this.passwordHash,
    this.rol = 'cliente',
    this.tokenSesion,
    this.fechaRegistro,
    this.ultimaSincronizacion,
  });

  factory Perfil.fromMap(Map<String, dynamic> map) {
    return Perfil(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      email: map['email'] as String?,
      telefono: map['telefono'] as String?,
      fotoUrl: map['foto_url'] as String?,
      passwordHash: map['password_hash'] as String?,
      rol: map['rol'] as String? ?? 'cliente',
      tokenSesion: map['token_sesion'] as String?,
      fechaRegistro: map['fecha_registro'] != null
          ? DateTime.tryParse(map['fecha_registro'] as String)
          : null,
      ultimaSincronizacion: map['ultima_sincronizacion'] != null
          ? DateTime.tryParse(map['ultima_sincronizacion'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'foto_url': fotoUrl,
      'password_hash': passwordHash,
      'rol': rol,
      'token_sesion': tokenSesion,
      'fecha_registro': fechaRegistro?.toIso8601String(),
      'ultima_sincronizacion': ultimaSincronizacion?.toIso8601String(),
    };
  }

  Perfil copyWith({
    String? nombre,
    String? email,
    String? telefono,
    String? fotoUrl,
    String? passwordHash,
    String? rol,
    String? tokenSesion,
    DateTime? ultimaSincronizacion,
  }) {
    return Perfil(
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      passwordHash: passwordHash ?? this.passwordHash,
      rol: rol ?? this.rol,
      tokenSesion: tokenSesion ?? this.tokenSesion,
      fechaRegistro: fechaRegistro,
      ultimaSincronizacion: ultimaSincronizacion ?? this.ultimaSincronizacion,
    );
  }
}
