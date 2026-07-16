class Categoria {
  final String id;
  final String nombre;
  final String? icono;
  final String? color;
  final int orden;

  Categoria({
    required this.id,
    required this.nombre,
    this.icono,
    this.color,
    this.orden = 0,
  });

  // Crear desde mapa (SQLite)
  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      icono: map['icono'] as String?,
      color: map['color'] as String?,
      orden: map['orden'] as int? ?? 0,
    );
  }

  // Convertir a mapa
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'icono': icono,
      'color': color,
      'orden': orden,
    };
  }

  // Copiar con cambios
  Categoria copyWith({
    String? id,
    String? nombre,
    String? icono,
    String? color,
    int? orden,
  }) {
    return Categoria(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      orden: orden ?? this.orden,
    );
  }
}