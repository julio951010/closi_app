/// Representa una foto asociada a un negocio o producto/servicio.
///
/// En la nube (Supabase Storage) vive la foto completa (`url`) y un
/// thumbnail comprimido (`urlThumbnail`). En local solo se persiste el
/// thumbnail bajo demanda (ver estrategia de caché liviana), guardado en
/// `rutaLocal`; la foto completa se descarga solo si hay conexión.
class Foto {
  final String id;
  final String tipo; // negocio | producto
  final String referenciaId;
  final String? url;
  final String? urlThumbnail;
  final String? rutaLocal;
  final int orden;

  Foto({
    required this.id,
    required this.tipo,
    required this.referenciaId,
    this.url,
    this.urlThumbnail,
    this.rutaLocal,
    this.orden = 0,
  });

  factory Foto.fromMap(Map<String, dynamic> map) {
    return Foto(
      id: map['id'] as String,
      tipo: map['tipo'] as String,
      referenciaId: map['referencia_id'] as String,
      url: map['url'] as String?,
      urlThumbnail: map['url_thumbnail'] as String?,
      rutaLocal: map['ruta_local'] as String?,
      orden: map['orden'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'referencia_id': referenciaId,
      'url': url,
      'url_thumbnail': urlThumbnail,
      'ruta_local': rutaLocal,
      'orden': orden,
    };
  }
}
