import 'package:flutter/material.dart';

class Negocio {
  final String id;
  final String nombre;
  final String categoria;
  final String? direccion;
  final String? telefono;
  final String? whatsapp;
  final String? email;
  final String? sitioWeb;
  final String? redesSociales;
  final String? horario;
  final String? descripcion;
  final String? metodoPago;
  final double lat;
  final double lon;
  final double? distancia;
  final List<String> fotos;
  final bool esFavorito;
  final double? calificacion;
  final int? totalResenas;
  final bool esDestacado;

  /// 'propio' = administrado por el usuario (tabla negocios_propios, editable).
  /// 'cache'  = descargado para consulta offline (tabla negocios_cache, solo lectura).
  final String origen;
  final String estado; // pendiente | aprobado | rechazado (solo aplica a 'propio')
  final String? thumbnailLocal;
  final DateTime? ultimoAcceso;

  Negocio({
    required this.id,
    required this.nombre,
    required this.categoria,
    this.direccion,
    this.telefono,
    this.whatsapp,
    this.email,
    this.sitioWeb,
    this.redesSociales,
    this.horario,
    this.descripcion,
    this.metodoPago,
    required this.lat,
    required this.lon,
    this.distancia,
    this.fotos = const [],
    this.esFavorito = false,
    this.calificacion,
    this.totalResenas,
    this.esDestacado = false,
    this.origen = 'cache',
    this.estado = 'aprobado',
    this.thumbnailLocal,
    this.ultimoAcceso,
  });

  /// Desde la tabla local `negocios_propios`
  factory Negocio.fromMapPropio(Map<String, dynamic> map) {
    return Negocio(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      categoria: map['categoria_id'] as String,
      direccion: map['direccion'] as String?,
      telefono: map['telefono'] as String?,
      whatsapp: map['whatsapp'] as String?,
      email: map['email'] as String?,
      sitioWeb: map['sitio_web'] as String?,
      redesSociales: map['redes_sociales'] as String?,
      horario: map['horario'] as String?,
      descripcion: map['descripcion'] as String?,
      metodoPago: map['metodo_pago'] as String?,
      lat: map['lat'] as double,
      lon: map['lon'] as double,
      origen: 'propio',
      estado: map['estado'] as String? ?? 'pendiente',
    );
  }

  /// Desde la tabla local `negocios_cache`
  factory Negocio.fromMapCache(Map<String, dynamic> map) {
    return Negocio(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      categoria: map['categoria_id'] as String? ?? '',
      descripcion: map['descripcion'] as String?,
      direccion: map['direccion'] as String?,
      telefono: map['telefono'] as String?,
      whatsapp: map['whatsapp'] as String?,
      email: map['email'] as String?,
      sitioWeb: map['sitio_web'] as String?,
      redesSociales: map['redes_sociales'] as String?,
      horario: map['horario'] as String?,
      lat: map['lat'] as double,
      lon: map['lon'] as double,
      calificacion: map['calificacion_promedio'] as double?,
      totalResenas: map['total_resenas'] as int?,
      esDestacado: (map['es_destacado'] as int? ?? 0) == 1,
      origen: 'cache',
      thumbnailLocal: map['thumbnail_local'] as String?,
      ultimoAcceso: map['ultimo_acceso'] != null
          ? DateTime.tryParse(map['ultimo_acceso'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMapPropio() {
    return {
      'id': id,
      'categoria_id': categoria,
      'nombre': nombre,
      'descripcion': descripcion,
      'direccion': direccion,
      'telefono': telefono,
      'whatsapp': whatsapp,
      'email': email,
      'sitio_web': sitioWeb,
      'redes_sociales': redesSociales,
      'horario': horario,
      'metodo_pago': metodoPago,
      'lat': lat,
      'lon': lon,
      'estado': estado,
    };
  }

  Map<String, dynamic> toMapCache() {
    return {
      'id': id,
      'categoria_id': categoria,
      'nombre': nombre,
      'descripcion': descripcion,
      'direccion': direccion,
      'telefono': telefono,
      'whatsapp': whatsapp,
      'email': email,
      'sitio_web': sitioWeb,
      'redes_sociales': redesSociales,
      'horario': horario,
      'metodo_pago': metodoPago,
      'lat': lat,
      'lon': lon,
      'calificacion_promedio': calificacion,
      'total_resenas': totalResenas ?? 0,
      'es_destacado': esDestacado ? 1 : 0,
      'thumbnail_local': thumbnailLocal,
    };
  }

  Negocio copyWith({bool? esFavorito, DateTime? ultimoAcceso, double? calificacion, int? totalResenas}) {
    return Negocio(
      id: id,
      nombre: nombre,
      categoria: categoria,
      direccion: direccion,
      telefono: telefono,
      whatsapp: whatsapp,
      email: email,
      sitioWeb: sitioWeb,
      redesSociales: redesSociales,
      horario: horario,
      descripcion: descripcion,
      metodoPago: metodoPago,
      lat: lat,
      lon: lon,
      distancia: distancia,
      fotos: fotos,
      esFavorito: esFavorito ?? this.esFavorito,
      calificacion: calificacion ?? this.calificacion,
      totalResenas: totalResenas ?? this.totalResenas,
      esDestacado: esDestacado,
      origen: origen,
      estado: estado,
      thumbnailLocal: thumbnailLocal,
      ultimoAcceso: ultimoAcceso ?? this.ultimoAcceso,
    );
  }

  static List<String> categorias = [
    'restaurante', 'cafeteria', 'farmacia', 'tienda',
    'taller', 'hotel', 'hospital', 'banco',
    'wifi', 'transporte', 'cultura', 'deporte',
  ];

  static Map<String, IconData> iconosCategoria = {
    'restaurante': Icons.restaurant,
    'cafeteria': Icons.coffee,
    'farmacia': Icons.local_pharmacy,
    'tienda': Icons.shopping_bag,
    'taller': Icons.build,
    'hotel': Icons.hotel,
    'hospital': Icons.local_hospital,
    'banco': Icons.account_balance,
    'wifi': Icons.wifi,
    'transporte': Icons.directions_bus,
    'cultura': Icons.theater_comedy,
    'deporte': Icons.fitness_center,
  };

  static Map<String, String> nombresCategoria = {
    'restaurante': 'Restaurante',
    'cafeteria': 'Cafetería',
    'farmacia': 'Farmacia',
    'tienda': 'Tienda',
    'taller': 'Taller',
    'hotel': 'Hotel',
    'hospital': 'Hospital',
    'banco': 'Banco',
    'wifi': 'WiFi',
    'transporte': 'Transporte',
    'cultura': 'Cultura',
    'deporte': 'Deporte',
  };

  static IconData getIcono(String categoria) {
    return iconosCategoria[categoria] ?? Icons.store;
  }

  static String getNombreCategoria(String categoria) {
    return nombresCategoria[categoria] ?? categoria;
  }

}