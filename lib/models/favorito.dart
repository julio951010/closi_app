class Favorito {
  final String id;
  final String usuarioId;
  final String negocioId;
  final DateTime fecha;
  final String estadoSync; // pendiente | sincronizado | error

  Favorito({
    required this.id,
    required this.usuarioId,
    required this.negocioId,
    required this.fecha,
    this.estadoSync = 'pendiente',
  });

  factory Favorito.fromMap(Map<String, dynamic> map) {
    return Favorito(
      id: map['id'] as String,
      usuarioId: map['usuario_id'] as String,
      negocioId: map['negocio_id'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      estadoSync: map['estado_sync'] as String? ?? 'pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'negocio_id': negocioId,
      'fecha': fecha.toIso8601String(),
      'estado_sync': estadoSync,
    };
  }

  Favorito copyWith({String? estadoSync}) {
    return Favorito(
      id: id,
      usuarioId: usuarioId,
      negocioId: negocioId,
      fecha: fecha,
      estadoSync: estadoSync ?? this.estadoSync,
    );
  }
}
