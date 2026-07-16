class Calificacion {
  final String id;
  final String usuarioId;
  final String negocioId;
  final int calificacion;
  final String? fecha;
  final String estadoSync;

  Calificacion({
    required this.id,
    required this.usuarioId,
    required this.negocioId,
    this.calificacion = 0,
    this.fecha,
    this.estadoSync = 'pendiente',
  });

  factory Calificacion.fromMap(Map<String, dynamic> map) {
    return Calificacion(
      id: map['id'] as String,
      usuarioId: map['usuario_id'] as String,
      negocioId: map['negocio_id'] as String,
      calificacion: map['calificacion'] != null ? (map['calificacion'] as num).toInt() : 0,
      fecha: map['fecha'] as String?,
      estadoSync: map['estado_sync'] as String? ?? 'pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'negocio_id': negocioId,
      'calificacion': calificacion,
      'fecha': fecha,
      'estado_sync': estadoSync,
    };
  }

  Calificacion copyWith({
    String? id,
    String? usuarioId,
    String? negocioId,
    int? calificacion,
    String? fecha,
    String? estadoSync,
  }) {
    return Calificacion(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      negocioId: negocioId ?? this.negocioId,
      calificacion: calificacion ?? this.calificacion,
      fecha: fecha ?? this.fecha,
      estadoSync: estadoSync ?? this.estadoSync,
    );
  }
}
