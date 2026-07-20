import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import 'package:sqflite/sqflite.dart';
import '../database/pg_connection.dart';
import '../database/database_helper.dart';
import '../database/negocio_dao.dart';
import '../models/negocio.dart';
import '../models/producto_servicio.dart';
import '../models/opinion.dart';
import 'sesion_service.dart';

/// Servicio central para obtener negocios según la ubicación del usuario y filtros.
class NegocioService {
  NegocioService._();

  static final NegocioDao _negocioDao = NegocioDao();

  /// Notifica a la UI si PostgreSQL está accesible en este momento.
  static final postgresDisponible = ValueNotifier<bool>(false);

  /// Se incrementa cada vez que se actualiza la caché local, para que
  /// las pantallas puedan recargar negocios sin depender de la ubicación.
  static final cacheActualizada = ValueNotifier<int>(0);

  static List<Negocio> _ultimosNegocios = [];
  static bool _cargando = false;
  static bool _consultando = false;

  /// Stream al que las pantallas se suscriben para recibir los negocios
  /// actualizados cuando cambia la ubicación.
  static final _controller = StreamController<List<Negocio>>.broadcast();
  static Stream<List<Negocio>> get stream => _controller.stream;
  static List<Negocio> get ultimosNegocios => _ultimosNegocios;
  static bool get cargando => _cargando;

  /// Intenta una conexión ligera a PostgreSQL y actualiza [postgresDisponible].
  static Future<bool> verificarConexion() async {
    try {
      final conn = await abrirConexionPostgres();
      await conn.close();
      postgresDisponible.value = true;
      return true;
    } catch (e) {
      debugPrint('verificarConexion error: $e');
      postgresDisponible.value = false;
      return false;
    }
  }

  /// Consulta negocios cerca de una ubicación con filtros opcionales.
  static Future<List<Negocio>> consultarCercaDe({
    required double lat,
    required double lon,
    double radioKm = 15,
    String? texto,
    String? categoria,
    double? calificacionMinima,
    String? metodoPago,
  }) async {
    _cargando = true;
    if (_consultando) {
      _cargando = false;
      return _ultimosNegocios;
    }
    _consultando = true;

    // --- Intentar PostgreSQL ---
    try {
      final negocios = await _consultarPostgres(
        lat, lon, radioKm,
        texto: texto,
        categoria: categoria,
        calificacionMinima: calificacionMinima,
        metodoPago: metodoPago,
      );
      if (negocios.isNotEmpty) {
        debugPrint('NegocioService: ${negocios.length} negocios desde PostgreSQL');
        postgresDisponible.value = true;
        _ultimosNegocios = negocios;
        _cargando = false;
        _consultando = false;
        _controller.add(negocios);
        unawaited(_negocioDao.guardarLoteCache(negocios));
        unawaited(_actualizarCacheCompleto());
        return negocios;
      } else {
        debugPrint('NegocioService: PostgreSQL respondió 0 negocios');
      }
    } catch (e) {
      postgresDisponible.value = false;
      debugPrint('NegocioService: PostgreSQL falló — $e');
    }

    // --- Fallback: cache local ---
    _cargando = false;
    _consultando = false;

    if (_ultimosNegocios.isNotEmpty) {
      return _ultimosNegocios;
    }

    var cached = await _negocioDao.obtenerTodosCache();
    if (cached.isNotEmpty) {
      if (texto != null && texto.isNotEmpty) {
        final q = texto.toLowerCase();
        cached = cached.where((n) =>
        n.nombre.toLowerCase().contains(q) ||
            n.categoria.toLowerCase().contains(q) ||
            (n.descripcion?.toLowerCase().contains(q) ?? false)).toList();
      }
      if (categoria != null) {
        cached = cached.where((n) => n.categoria == categoria.toLowerCase()).toList();
      }
      if (calificacionMinima != null) {
        cached = cached.where((n) => (n.calificacion ?? 0) >= calificacionMinima).toList();
      }
      if (metodoPago != null) {
        cached = cached.where((n) => n.metodoPago == metodoPago).toList();
      }
      if (cached.isNotEmpty) {
        _ultimosNegocios = cached;
        _controller.add(cached);
        return cached;
      }
    }

    _controller.add([]);
    return [];
  }

  /// Consulta PostgreSQL con filtros de distancia, texto y categoría.
  static Future<List<Negocio>> _consultarPostgres(
      double lat, double lon, double radioKm, {
        String? texto,
        String? categoria,
        double? calificacionMinima,
        String? metodoPago,
      }) async {
    final conn = await abrirConexionPostgres();
    try {
      final conditions = <String>['n.estado = \'aprobado\''];
      final params = <String, dynamic>{
        'lat': lat,
        'lon': lon,
        'radioKm': radioKm,
      };

      if (texto != null && texto.isNotEmpty) {
        conditions.add('(LOWER(n.nombre) LIKE @texto OR LOWER(n.descripcion) LIKE @texto)');
        params['texto'] = '%${texto.toLowerCase()}%';
      }
      if (categoria != null) {
        conditions.add('n.categoria_id = @categoria');
        params['categoria'] = categoria.toLowerCase();
      }
      if (metodoPago != null) {
        conditions.add('n.metodo_pago = @metodoPago');
        params['metodoPago'] = metodoPago;
      }

      final whereClause = conditions.join(' AND ');

      final sql = '''
        SELECT n.*,
          ST_Y(n.ubicacion::geometry) AS lat,
          ST_X(n.ubicacion::geometry) AS lon,
          ST_Distance(n.ubicacion, ST_MakePoint(@lon, @lat)::geography) / 1000 AS distancia_km
        FROM negocios n
        WHERE $whereClause
          AND ST_DWithin(n.ubicacion, ST_MakePoint(@lon, @lat)::geography, @radioKm::double precision * 1000)
        ORDER BY distancia_km ASC
      ''';

      final result = await conn.execute(Sql.named(sql), parameters: params);
      return result.map((row) {
        final map = row.toColumnMap();
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
          metodoPago: map['metodo_pago'] as String?,
          lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
          lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
          distancia: (map['distancia_km'] as num?)?.toDouble(),
          esDestacado: map['es_destacado'] is bool ? map['es_destacado'] as bool : (map['es_destacado'] as int? ?? 0) == 1,
          origen: 'cache',
          estado: 'aprobado',
        );
      }).toList();
    } finally {
      await conn.close();
    }
  }

  /// Descarga desde PostgreSQL y actualiza SQLite con:
  /// - categorías
  /// - datos del usuario autenticado
  /// - negocios del usuario autenticado
  /// - favoritos del usuario autenticado
  static Future<void> _actualizarCacheCompleto() async {
    final usuarioId = SesionService.usuarioId;
    if (usuarioId.isEmpty) return;

    try {
      await _descargarCategorias();
      await _descargarUsuario(usuarioId);
      await _descargarNegociosPropios(usuarioId);
      await _descargarFavoritos(usuarioId);
      debugPrint('NegocioService: caché local actualizada desde PostgreSQL');
    } catch (e) {
      debugPrint('NegocioService: error al actualizar caché completo — $e');
    }
  }

  /// Descarga categorías desde PostgreSQL y las guarda en SQLite.
  /// Usa INSERT OR REPLACE para no violar FOREIGN KEY de negocios.
  static Future<void> _descargarCategorias() async {
    final conn = await abrirConexionPostgres();
    try {
      final result = await conn.execute(Sql.named('SELECT * FROM categorias ORDER BY orden ASC'));
      if (result.isEmpty) return;
      final db = await DatabaseHelper.database;

      for (final row in result) {
        final map = row.toColumnMap();
        await db.insert('categorias', {
          'id': map['id'] as String,
          'nombre': map['nombre'] as String,
          'icono': map['icono'] as String?,
          'color': map['color'] as String?,
          'orden': map['orden'] as int? ?? 0,
          'version': map['version'] as int? ?? 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } finally {
      await conn.close();
    }
  }

  /// Descarga datos del usuario desde PostgreSQL.
  static Future<void> _descargarUsuario(String usuarioId) async {
    final conn = await abrirConexionPostgres();
    try {
      final result = await conn.execute(
        Sql.named('SELECT * FROM usuarios WHERE id = @id'),
        parameters: {'id': usuarioId},
      );
      if (result.isEmpty) return;
      final map = result.first.toColumnMap();
      final db = await DatabaseHelper.database;
      await db.insert('usuario', {
        'id': map['id'] as String,
        'nombre': map['nombre'] as String,
        'email': map['email'] as String?,
        'telefono': map['telefono'] as String?,
        'password_hash': map['password_hash'] as String?,
        'rol': map['rol'] as String? ?? 'cliente',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } finally {
      await conn.close();
    }
  }

  /// Descarga negocios propios del usuario desde PostgreSQL.
  static Future<void> _descargarNegociosPropios(String usuarioId) async {
    final conn = await abrirConexionPostgres();
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT id, propietario_id, categoria_id, nombre, descripcion, direccion,
            telefono, whatsapp, email, sitio_web, redes_sociales, horario, metodo_pago,
            ST_Y(ubicacion::geometry) AS lat, ST_X(ubicacion::geometry) AS lon,
            estado, plan_suscripcion, fecha_expiracion_plan, creado_en, actualizado_en
          FROM negocios WHERE propietario_id = @propietario_id
        '''),
        parameters: {'propietario_id': usuarioId},
      );
      if (result.isEmpty) return;
      final db = await DatabaseHelper.database;

      for (final row in result) {
        final map = row.toColumnMap();
        await db.insert('negocios_propios', {
          'id': map['id'] as String,
          'categoria_id': map['categoria_id'] as String,
          'nombre': map['nombre'] as String,
          'descripcion': map['descripcion'] as String?,
          'direccion': map['direccion'] as String?,
          'telefono': map['telefono'] as String?,
          'whatsapp': map['whatsapp'] as String?,
          'email': map['email'] as String?,
          'sitio_web': map['sitio_web'] as String?,
          'redes_sociales': map['redes_sociales'] as String?,
          'horario': map['horario'] as String?,
          'metodo_pago': map['metodo_pago'] as String?,
          'lat': (map['lat'] as num?)?.toDouble(),
          'lon': (map['lon'] as num?)?.toDouble(),
          'estado': map['estado'] as String? ?? 'pendiente',
          'plan_suscripcion': map['plan_suscripcion'] as String?,
          'fecha_expiracion_plan': map['fecha_expiracion_plan'] is DateTime
              ? (map['fecha_expiracion_plan'] as DateTime).toIso8601String()
              : map['fecha_expiracion_plan'] as String?,
          'creado_en': map['creado_en'] is DateTime
              ? (map['creado_en'] as DateTime).toIso8601String()
              : map['creado_en'] as String?,
          'actualizado_en': map['actualizado_en'] is DateTime
              ? (map['actualizado_en'] as DateTime).toIso8601String()
              : map['actualizado_en'] as String?,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } finally {
      await conn.close();
    }
  }

  /// Descarga favoritos del usuario desde PostgreSQL.
  /// Borra solo los del usuario actual y los reemplaza.
  static Future<void> _descargarFavoritos(String usuarioId) async {
    final conn = await abrirConexionPostgres();
    try {
      final result = await conn.execute(
        Sql.named('SELECT * FROM favoritos WHERE usuario_id = @usuario_id'),
        parameters: {'usuario_id': usuarioId},
      );
      final db = await DatabaseHelper.database;

      // Borrar solo los favoritos del usuario actual
      await db.delete('favoritos', where: 'usuario_id = ?', whereArgs: [usuarioId]);

      for (final row in result) {
        final map = row.toColumnMap();
        await db.insert('favoritos', {
          'id': map['id'] as String,
          'usuario_id': usuarioId,
          'negocio_id': map['negocio_id'] as String,
          'fecha': map['creado_en'] is DateTime
              ? (map['creado_en'] as DateTime).toIso8601String()
              : map['creado_en'] as String?,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } finally {
      await conn.close();
    }
  }

  /// Consulta los productos/servicios de un negocio desde PostgreSQL.
  static Future<List<ProductoServicio>> consultarProductos(String negocioId) async {
    try {
      final conn = await abrirConexionPostgres();
      try {
        final result = await conn.execute(
          Sql.named('SELECT * FROM productos_servicios WHERE negocio_id = @negocio_id AND disponible = true ORDER BY creado_en ASC'),
          parameters: {'negocio_id': negocioId},
        );
        return result.map((row) {
          final map = Map<String, dynamic>.from(row.toColumnMap());
          if (map['creado_en'] is DateTime) map['creado_en'] = (map['creado_en'] as DateTime).toIso8601String();
          if (map['actualizado_en'] is DateTime) map['actualizado_en'] = (map['actualizado_en'] as DateTime).toIso8601String();
          if (map['disponible'] is bool) map['disponible'] = (map['disponible'] as bool) ? 1 : 0;
          if (map['precio'] is String) map['precio'] = double.tryParse(map['precio'] as String);
          return ProductoServicio.fromMap(map);
        }).toList();
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('NegocioService: error al consultar productos — $e');
      return [];
    }
  }

  /// Consulta el promedio de calificaciones de un negocio desde PostgreSQL.
  static Future<Map<String, dynamic>> consultarCalificacionPromedio(String negocioId) async {
    try {
      final conn = await abrirConexionPostgres();
      try {
        final result = await conn.execute(
          Sql.named('SELECT calificacion FROM calificaciones WHERE negocio_id = @negocio_id'),
          parameters: {'negocio_id': negocioId},
        );
        if (result.isEmpty) return {'total': 0, 'promedio': 0.0};
        final total = result.length;
        final promedio = result.fold<double>(0.0, (sum, row) => sum + ((row.toColumnMap()['calificacion'] as num?)?.toDouble() ?? 0.0)) / total;
        return {'total': total, 'promedio': promedio};
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('NegocioService: error al consultar calificaciones — $e');
      return {'total': 0, 'promedio': 0.0};
    }
  }

  /// Consulta las opiniones de un negocio desde PostgreSQL.
  static Future<List<Opinion>> consultarOpiniones(String negocioId) async {
    try {
      final conn = await abrirConexionPostgres();
      try {
        final result = await conn.execute(
          Sql.named('''
            SELECT o.id, o.usuario_id, o.negocio_id, o.comentario, o.anonimo, o.creado_en, u.nombre AS usuario_nombre
            FROM opiniones o
            LEFT JOIN usuarios u ON o.usuario_id = u.id
            WHERE o.negocio_id = @negocio_id
            ORDER BY o.creado_en DESC
          '''),
          parameters: {'negocio_id': negocioId},
        );
        return result.map((row) {
          final map = Map<String, dynamic>.from(row.toColumnMap());
          map['nombre_usuario'] = map['usuario_nombre'] as String?;
          map['fecha'] = map['creado_en'];
          if (map['fecha'] is DateTime) map['fecha'] = (map['fecha'] as DateTime).toIso8601String();
          return Opinion.fromMap(map);
        }).toList();
      } finally {
        await conn.close();
      }
    } catch (e) {
      debugPrint('NegocioService: error al consultar opiniones — $e');
      return [];
    }
  }

  /// Parsea un valor dinámico a double o null.
  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}