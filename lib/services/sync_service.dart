import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/cola_sincronizacion_dao.dart';
import '../database/negocio_dao.dart';
import '../models/negocio.dart';
import '../repositories/usuario_repository.dart';
import 'connectivity_service.dart';
import 'negocio_service.dart';
import 'package:postgres/postgres.dart';
import '../database/pg_connection.dart';

/// Motor de sincronización offline → nube.
///
/// Lee `cola_sincronizacion` (poblada por los DAOs cada vez que el usuario
/// crea/edita/borra algo local) y aplica esos cambios contra Supabase.
class SyncService {
  static final ColaSincronizacionDao _cola = ColaSincronizacionDao();
  static final UsuarioRepository _usuarioRepo = UsuarioRepository();

  static bool _sincronizando = false;

  /// Procesa toda la cola pendiente. Segura de llamar varias veces seguidas
  /// (ej. desde main() y también desde el listener de conectividad): si ya
  /// hay una sincronización en curso, la llamada nueva no hace nada.
  static Future<void> sincronizar() async {
    if (_sincronizando) return;
    if (!await ConnectivityService.hayConexion()) return;

    debugPrint('SyncService: sincronizando...');
    _sincronizando = true;
    try {
      final perfil = await _usuarioRepo.obtenerPerfilActual();
      if (perfil == null) return; // sin sesión local, nada que subir todavía

      await _asegurarUsuarioEnNube(perfil.id, perfil.nombre, perfil.email, passwordHash: perfil.passwordHash);

      final pendientes = await _cola.obtenerPendientes();
      for (final item in pendientes) {
        try {
          await _procesarItem(item, perfil.id);
          await _cola.marcarCompletado(item['id'] as int);
        } catch (e) {
          await _cola.registrarFallo(item['id'] as int, e.toString());
          // No relanzamos: un item fallido no debe bloquear el resto de la cola.
        }
      }
      debugPrint('SyncService: sincronización completada');
      await descargarNegociosCache();
    } catch (e) {
      debugPrint('SyncService: error al sincronizar — $e');
    } finally {
      _sincronizando = false;
    }
  }

  /// El usuario local debe existir en `usuarios` (nube) antes de poder
  /// insertar negocios/favoritos que lo referencian como FK.
  static Future<void> _asegurarUsuarioEnNube(
      String id, String nombre, String? email,
      {String? passwordHash}) async {
    final conn = await abrirConexionPostgres();
    try {
      await conn.execute(Sql.named('''
        INSERT INTO usuarios (id, nombre, email, password_hash)
        VALUES (@id, @nombre, @email, @passwordHash)
        ON CONFLICT (id) DO UPDATE SET
          nombre = EXCLUDED.nombre,
          email = EXCLUDED.email,
          password_hash = COALESCE(EXCLUDED.password_hash, usuarios.password_hash)
      '''), parameters: {
        'id': id,
        'nombre': nombre,
        'email': email,
        'passwordHash': passwordHash,
      });
    } finally {
      await conn.close();
    }
  }

  static Future<void> _procesarItem(
      Map<String, dynamic> item, String usuarioId) async {
    final tabla = item['tabla'] as String;
    final operacion = item['operacion'] as String;
    final registroId = item['registro_id'] as String;
    final payloadStr = item['payload'] as String?;
    final payload = payloadStr != null
        ? jsonDecode(payloadStr) as Map<String, dynamic>
        : <String, dynamic>{};

    switch (tabla) {
      case 'negocios_propios':
        await _sincronizarNegocio(operacion, registroId, payload, usuarioId);
        break;
      case 'favoritos':
        await _sincronizarFavorito(operacion, payload);
        break;
      case 'calificaciones':
        await _sincronizarCalificacion(operacion, payload);
        break;
      case 'opiniones':
        await _sincronizarOpinion(operacion, payload);
        break;
      case 'productos_servicios':
        await _sincronizarProducto(operacion, payload);
        break;
      case 'resenas':
        // Tabla legacy eliminada; omitir entradas antiguas en la cola
        break;
      default:
        throw Exception('Sin manejador de sincronización para la tabla "$tabla"');
    }
  }

  static Future<void> _sincronizarNegocio(String operacion,
      String id, Map<String, dynamic> data, String propietarioId) async {
    final conn = await abrirConexionPostgres();
    try {
      if (operacion == 'delete') {
        await conn.execute(Sql.named('DELETE FROM negocios WHERE id = @id'),
            parameters: {'id': id});
        return;
      }

      // 'ubicacion' es GEOGRAPHY(POINT) en el esquema real (local y
      // Supabase); no existen columnas lat/lon planas. ST_MakePoint espera
      // (longitud, latitud) en ese orden.
      await conn.execute(Sql.named('''
        INSERT INTO negocios (id, propietario_id, categoria_id, nombre, descripcion, direccion, telefono, whatsapp, email, sitio_web, redes_sociales, horario, metodo_pago, ubicacion, estado)
        VALUES (@id, @propietarioId, @categoriaId, @nombre, @descripcion, @direccion, @telefono, @whatsapp, @email, @sitioWeb, @redesSociales, @horario, @metodoPago, ST_MakePoint(@lon, @lat)::geography, @estado)
        ON CONFLICT (id) DO UPDATE SET
          propietario_id = EXCLUDED.propietario_id,
          categoria_id = EXCLUDED.categoria_id,
          nombre = EXCLUDED.nombre,
          descripcion = EXCLUDED.descripcion,
          direccion = EXCLUDED.direccion,
          telefono = EXCLUDED.telefono,
          whatsapp = EXCLUDED.whatsapp,
          email = EXCLUDED.email,
          sitio_web = EXCLUDED.sitio_web,
          redes_sociales = EXCLUDED.redes_sociales,
          horario = EXCLUDED.horario,
          metodo_pago = EXCLUDED.metodo_pago,
          ubicacion = EXCLUDED.ubicacion,
          estado = EXCLUDED.estado
      '''), parameters: {
        'id': id,
        'propietarioId': propietarioId,
        'categoriaId': data['categoria_id'],
        'nombre': data['nombre'],
        'descripcion': data['descripcion'],
        'direccion': data['direccion'],
        'telefono': data['telefono'],
        'whatsapp': data['whatsapp'],
        'email': data['email'],
        'sitioWeb': data['sitio_web'],
        'redesSociales': data['redes_sociales'],
        'horario': data['horario'],
        'metodoPago': data['metodo_pago'],
        'lat': (data['lat'] as num?)?.toDouble(),
        'lon': (data['lon'] as num?)?.toDouble(),
        'estado': data['estado'],
      });
    } finally {
      await conn.close();
    }
  }

  static Future<void> _sincronizarFavorito(
      String operacion, Map<String, dynamic> data) async {
    final conn = await abrirConexionPostgres();
    try {
      if (operacion == 'create') {
        await conn.execute(Sql.named('''
          INSERT INTO favoritos (usuario_id, negocio_id)
          VALUES (@usuarioId, @negocioId)
          ON CONFLICT (usuario_id, negocio_id) DO NOTHING
        '''), parameters: {
          'usuarioId': data['usuario_id'],
          'negocioId': data['negocio_id'],
        });
      } else if (operacion == 'delete') {
        await conn.execute(Sql.named('''
          DELETE FROM favoritos WHERE usuario_id = @usuarioId AND negocio_id = @negocioId
        '''), parameters: {
          'usuarioId': data['usuario_id'] as String,
          'negocioId': data['negocio_id'] as String,
        });
      }
    } finally {
      await conn.close();
    }
  }

  static Future<void> _sincronizarCalificacion(
      String operacion, Map<String, dynamic> data) async {
    final conn = await abrirConexionPostgres();
    try {
      if (operacion == 'upsert') {
        await conn.execute(Sql.named('''
          INSERT INTO calificaciones (id, usuario_id, negocio_id, calificacion, creado_en)
          VALUES (@id, @usuarioId, @negocioId, @calificacion, @creadoEn)
          ON CONFLICT (id) DO UPDATE SET
            usuario_id = EXCLUDED.usuario_id,
            negocio_id = EXCLUDED.negocio_id,
            calificacion = EXCLUDED.calificacion,
            creado_en = EXCLUDED.creado_en
        '''), parameters: {
          'id': data['id'],
          'usuarioId': data['usuario_id'],
          'negocioId': data['negocio_id'],
          'calificacion': data['calificacion'],
          'creadoEn': data['fecha'] ?? DateTime.now().toIso8601String(),
        });
      } else if (operacion == 'delete') {
        await conn.execute(Sql.named('DELETE FROM calificaciones WHERE id = @id'),
            parameters: {'id': data['id'] as String});
      }
    } finally {
      await conn.close();
    }
  }

  static Future<void> _sincronizarOpinion(
      String operacion, Map<String, dynamic> data) async {
    final conn = await abrirConexionPostgres();
    try {
      if (operacion == 'upsert') {
        await conn.execute(Sql.named('''
          INSERT INTO opiniones (id, usuario_id, negocio_id, comentario, anonimo, creado_en)
          VALUES (@id, @usuarioId, @negocioId, @comentario, @anonimo, @creadoEn)
          ON CONFLICT (id) DO UPDATE SET
            usuario_id = EXCLUDED.usuario_id,
            negocio_id = EXCLUDED.negocio_id,
            comentario = EXCLUDED.comentario,
            anonimo = EXCLUDED.anonimo,
            creado_en = EXCLUDED.creado_en
        '''), parameters: {
          'id': data['id'],
          'usuarioId': data['usuario_id'],
          'negocioId': data['negocio_id'],
          'comentario': data['comentario'],
          'anonimo': data['anonimo'] == 1 || data['anonimo'] == true ? true : false,
          'creadoEn': data['fecha'] ?? DateTime.now().toIso8601String(),
        });
      } else if (operacion == 'delete') {
        await conn.execute(Sql.named('DELETE FROM opiniones WHERE id = @id'),
            parameters: {'id': data['id'] as String});
      }
    } finally {
      await conn.close();
    }
  }

  static Future<void> _sincronizarProducto(
      String operacion, Map<String, dynamic> data) async {
    final conn = await abrirConexionPostgres();
    try {
      if (operacion == 'delete') {
        await conn.execute(Sql.named('DELETE FROM productos_servicios WHERE id = @id'),
            parameters: {'id': data['id'] as String});
        return;
      }
      await conn.execute(Sql.named('''
        INSERT INTO productos_servicios (id, negocio_id, nombre, descripcion, precio, disponible, creado_en, actualizado_en)
        VALUES (@id, @negocioId, @nombre, @descripcion, @precio, @disponible, @creadoEn, @actualizadoEn)
        ON CONFLICT (id) DO UPDATE SET
          negocio_id = EXCLUDED.negocio_id,
          nombre = EXCLUDED.nombre,
          descripcion = EXCLUDED.descripcion,
          precio = EXCLUDED.precio,
          disponible = EXCLUDED.disponible,
          creado_en = EXCLUDED.creado_en,
          actualizado_en = EXCLUDED.actualizado_en
      '''), parameters: {
        'id': data['id'],
        'negocioId': data['negocio_id'],
        'nombre': data['nombre'],
        'descripcion': data['descripcion'],
        'precio': data['precio'],
        'disponible': data['disponible'] == 1 || data['disponible'] == true ? true : false,
        'creadoEn': data['creado_en'],
        'actualizadoEn': data['actualizado_en'],
      });
    } finally {
      await conn.close();
    }
  }

  /// Descarga los negocios aprobados desde Supabase y los guarda en la
  /// caché local (`negocios_cache`). Se invoca automáticamente al arrancar
  /// la app después de [sincronizar].
  static Future<void> descargarNegociosCache() async {
    if (!await ConnectivityService.hayConexion()) return;

    final conn = await abrirConexionPostgres();
    try {
      final result = await conn.execute(Sql.named('''
        SELECT id, categoria_id, nombre, descripcion, direccion, telefono, horario,
          ST_Y(ubicacion::geometry) AS lat, ST_X(ubicacion::geometry) AS lon,
          calificacion_promedio, total_resenas, es_destacado, estado
        FROM negocios
        WHERE estado = @estado
        ORDER BY nombre ASC
      '''), parameters: {'estado': 'aprobado'});

      if (result.isEmpty) return;

      final negocios = result.map((row) {
        return Negocio.fromMapCache(<String, dynamic>{
          'id': row[0],
          'categoria_id': row[1],
          'nombre': row[2],
          'descripcion': row[3],
          'direccion': row[4],
          'telefono': row[5],
          'horario': row[6],
          'lat': _parseDouble(row[7]),
          'lon': _parseDouble(row[8]),
          'calificacion_promedio': _parseDouble(row[9]),
          'total_resenas': _parseInt(row[10]),
          'es_destacado': _parseInt(row[11]),
          'estado': row[12],
        });
      }).toList();

      await NegocioDao().guardarLoteCache(negocios);
      NegocioService.cacheActualizada.value++;
      debugPrint('SyncService: ${negocios.length} negocios descargados a la caché local');
    } catch (e) {
      debugPrint('SyncService: error al descargar caché — $e');
    } finally {
      await conn.close();
    }
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
