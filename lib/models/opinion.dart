class Opinion {
  final String id;
  final String usuarioId;
  final String negocioId;
  final String? comentario;
  final bool anonimo;
  final String? fecha;
  final String? nombreUsuario;
  final String estadoSync;

  Opinion({
    required this.id,
    required this.usuarioId,
    required this.negocioId,
    this.comentario,
    this.anonimo = false,
    this.fecha,
    this.nombreUsuario,
    this.estadoSync = 'pendiente',
  });

  factory Opinion.fromMap(Map<String, dynamic> map) {
    return Opinion(
      id: map['id'] as String,
      usuarioId: map['usuario_id'] as String,
      negocioId: map['negocio_id'] as String,
      comentario: map['comentario'] as String?,
      anonimo: map['anonimo'] == 1 || map['anonimo'] == true,
      fecha: map['fecha'] as String?,
      nombreUsuario: map['nombre_usuario'] as String?,
      estadoSync: map['estado_sync'] as String? ?? 'pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'negocio_id': negocioId,
      'comentario': comentario,
      'anonimo': anonimo ? 1 : 0,
      'fecha': fecha,
      'nombre_usuario': nombreUsuario,
      'estado_sync': estadoSync,
    };
  }

  Opinion copyWith({
    String? id,
    String? usuarioId,
    String? negocioId,
    String? comentario,
    bool? anonimo,
    String? fecha,
    String? nombreUsuario,
    String? estadoSync,
  }) {
    return Opinion(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      negocioId: negocioId ?? this.negocioId,
      comentario: comentario ?? this.comentario,
      anonimo: anonimo ?? this.anonimo,
      fecha: fecha ?? this.fecha,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      estadoSync: estadoSync ?? this.estadoSync,
    );
  }
}
