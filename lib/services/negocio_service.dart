import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';
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

  static String _host = DatabaseConfig.host;
  static int _port = DatabaseConfig.port;
  static String _database = DatabaseConfig.database;
  static String _usuario = DatabaseConfig.username;
  static String _password = DatabaseConfig.password;

  /// Notifica a la UI si PostgreSQL está accesible en este momento.
  static final postgresDisponible = ValueNotifier<bool>(false);

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
      final conn = await Connection.open(Endpoint(
        host: _host,
        port: _port,
        database: _database,
        username: _usuario,
        password: _password,
      ), settings: const ConnectionSettings(sslMode: SslMode.disable));
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
  ///
  /// 1. Intenta PostgreSQL. Si funciona, actualiza la caché SQLite con
  ///    categorías, datos del usuario, negocios propios y favoritos.
  /// 2. Si PostgreSQL falla, retorna los datos desde la caché SQLite.
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

    // Si ya tenemos datos de una consulta anterior, retornarlos sin tocar el stream
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
    final conn = await Connection.open(Endpoint(
      host: _host,
      port: _port,
      database: _database,
      username: _usuario,
      password: _password,
    ));
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
        SELECT * FROM (
          SELECT n.*, (
            6371 * acos(
              cos(radians(@lat)) * cos(radians(n.lat)) *
              cos(radians(n.lon) - radians(@lon)) +
              sin(radians(@lat)) * sin(radians(n.lat))
            )
          ) AS distancia_km
          FROM negocios n
          WHERE $whereClause
        ) sub
        WHERE sub.distancia_km <= @radioKm
        ORDER BY sub.distancia_km ASC
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
          lat: (map['lat'] as num).toDouble(),
          lon: (map['lon'] as num).toDouble(),
          distancia: (map['distancia_km'] as num?)?.toDouble(),
          esDestacado: map['es_destacado'] as bool? ?? false,
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
      // --- 1. Categorías ---
      await _descargarCategorias();

      // --- 2. Datos del usuario autenticado ---
      await _descargarUsuario(usuarioId);

      // --- 3. Negocios del usuario autenticado ---
      await _descargarNegociosPropios(usuarioId);

      // --- 4. Favoritos del usuario autenticado ---
      await _descargarFavoritos(usuarioId);

      debugPrint('NegocioService: caché local actualizada desde PostgreSQL');
    } catch (e) {
      debugPrint('NegocioService: error al actualizar caché completo — $e');
    }
  }

  static Future<void> _descargarCategorias() async {
    final conn = await Connection.open(Endpoint(
      host: _host,
      port: _port,
      database: _database,
      username: _usuario,
      password: _password,
    ));
    try {
      final result = await conn.execute(Sql.named('SELECT * FROM categorias ORDER BY orden ASC'));
      if (result.isEmpty) return;
      final db = await DatabaseHelper.database;
      await db.delete('categorias');
      for (final row in result) {
        final map = row.toColumnMap();
        await db.insert('categorias', {
          'id': map['id'] as String,
          'nombre': map['nombre'] as String,
          'icono': map['icono'] as String?,
          'color': map['color'] as String?,
          'orden': map['orden'] as int? ?? 0,
          'version': map['version'] as int? ?? 1,
        });
      }
    } finally {
      await conn.close();
    }
  }

  static Future<void> _descargarUsuario(String usuarioId) async {
    final conn = await Connection.open(Endpoint(
      host: _host,
      port: _port,
      database: _database,
      username: _usuario,
      password: _password,
    ));
    try {
      final result = await conn.execute(
        Sql.named('SELECT * FROM usuarios WHERE id = @id'),
        parameters: {'id': usuarioId},
      );
      if (result.isEmpty) return;
      final map = result.first.toColumnMap();
      final db = await DatabaseHelper.database;
      await db.delete('usuario');
      await db.insert('usuario', {
        'id': map['id'] as String,
        'nombre': map['nombre'] as String,
        'email': map['email'] as String?,
        'telefono': map['telefono'] as String?,
        'password_hash': map['password_hash'] as String?,
        'rol': map['rol'] as String? ?? 'cliente',
      });
    } finally {
      await conn.close();
    }
  }

  static Future<void> _descargarNegociosPropios(String usuarioId) async {
    final conn = await Connection.open(Endpoint(
      host: _host,
      port: _port,
      database: _database,
      username: _usuario,
      password: _password,
    ));
    try {
      final result = await conn.execute(
        Sql.named('SELECT * FROM negocios WHERE propietario_id = @propietario_id'),
        parameters: {'propietario_id': usuarioId},
      );
      if (result.isEmpty) return;
      final db = await DatabaseHelper.database;
      await db.delete('negocios_propios');
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
          'lat': _parseDouble(map['lat']),
          'lon': _parseDouble(map['lon']),
          'estado': map['estado'] as String? ?? 'pendiente',
          'plan_suscripcion': map['plan_suscripcion'] as String?,
          'fecha_expiracion_plan': map['fecha_expiracion_plan'] is DateTime
              ? (map['fecha_expiracion_plan'] as DateTime).toIso8601String() : map['fecha_expiracion_plan'] as String?,
          'creado_en': map['creado_en'] is DateTime
              ? (map['creado_en'] as DateTime).toIso8601String() : map['creado_en'] as String?,
          'actualizado_en': map['actualizado_en'] is DateTime
              ? (map['actualizado_en'] as DateTime).toIso8601String() : map['actualizado_en'] as String?,
        });
      }
    } finally {
      await conn.close();
    }
  }

  static Future<void> _descargarFavoritos(String usuarioId) async {
    final conn = await Connection.open(Endpoint(
      host: _host,
      port: _port,
      database: _database,
      username: _usuario,
      password: _password,
    ));
    try {
      final result = await conn.execute(
        Sql.named('SELECT * FROM favoritos WHERE usuario_id = @usuario_id'),
        parameters: {'usuario_id': usuarioId},
      );
      if (result.isEmpty) return;
      final db = await DatabaseHelper.database;
      await db.delete('favoritos');
      for (final row in result) {
        final map = row.toColumnMap();
        await db.insert('favoritos', {
          'id': map['id'] as String,
          'usuario_id': usuarioId,
          'negocio_id': map['negocio_id'] as String,
          'fecha': map['creado_en'] is DateTime
              ? (map['creado_en'] as DateTime).toIso8601String() : map['creado_en'] as String?,
        });
      }
    } finally {
      await conn.close();
    }
  }

  /// Consulta los productos/servicios de un negocio desde PostgreSQL.
  /// Si falla la red, retorna lista vacía.
  static Future<List<ProductoServicio>> consultarProductos(String negocioId) async {
    try {
      final conn = await Connection.open(Endpoint(
        host: _host,
        port: _port,
        database: _database,
        username: _usuario,
        password: _password,
      ), settings: const ConnectionSettings(sslMode: SslMode.disable));
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
      final conn = await Connection.open(Endpoint(
        host: _host,
        port: _port,
        database: _database,
        username: _usuario,
        password: _password,
      ), settings: const ConnectionSettings(sslMode: SslMode.disable));
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
      final conn = await Connection.open(Endpoint(
        host: _host,
        port: _port,
        database: _database,
        username: _usuario,
        password: _password,
      ), settings: const ConnectionSettings(sslMode: SslMode.disable));
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

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
