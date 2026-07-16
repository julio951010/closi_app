class ProductoServicio {
  final String id;
  final String negocioId;
  final String nombre;
  final String? descripcion;
  final double? precio;
  final bool disponible;
  final String? fotoLocal;
  final String? creadoEn;
  final String? actualizadoEn;
  final String estadoSync;

  ProductoServicio({
    required this.id,
    required this.negocioId,
    required this.nombre,
    this.descripcion,
    this.precio,
    this.disponible = true,
    this.fotoLocal,
    this.creadoEn,
    this.actualizadoEn,
    this.estadoSync = 'pendiente',
  });

  factory ProductoServicio.fromMap(Map<String, dynamic> map) {
    return ProductoServicio(
      id: map['id'] as String,
      negocioId: map['negocio_id'] as String,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      precio: map['precio'] != null ? (map['precio'] as num).toDouble() : null,
      disponible: map['disponible'] == 1 || map['disponible'] == true,
      fotoLocal: map['foto_local'] as String?,
      creadoEn: map['creado_en'] as String?,
      actualizadoEn: map['actualizado_en'] as String?,
      estadoSync: map['estado_sync'] as String? ?? 'pendiente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'negocio_id': negocioId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'disponible': disponible ? 1 : 0,
      'foto_local': fotoLocal,
      'creado_en': creadoEn,
      'actualizado_en': actualizadoEn,
      'estado_sync': estadoSync,
    };
  }

  ProductoServicio copyWith({
    String? nombre,
    String? descripcion,
    double? precio,
    bool? disponible,
    String? fotoLocal,
  }) {
    return ProductoServicio(
      id: id,
      negocioId: negocioId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      disponible: disponible ?? this.disponible,
      fotoLocal: fotoLocal ?? this.fotoLocal,
      creadoEn: creadoEn,
      actualizadoEn: actualizadoEn,
      estadoSync: estadoSync,
    );
  }
}
