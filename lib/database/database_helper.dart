import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Gestor central de la base de datos local (SQLite).
///
/// Filosofía del esquema:
/// - `negocios_propios`: negocios que el usuario administra (dueño). Editables,
///   se sincronizan hacia la nube mediante `cola_sincronizacion`.
/// - `negocios_cache`: negocios de terceros descargados para consulta offline.
///   Solo lectura, con datos livianos (sin fotos completas, solo thumbnail).
///   Sujeta a límite de tamaño y purga LRU (ver `ultimo_acceso`).
/// - `cola_sincronizacion`: cambios locales pendientes de subir a Postgres/Supabase
///   cuando vuelva la conexión.
///
/// IMPORTANTE sobre `_crearEsquema`: usa CREATE TABLE/INDEX **IF NOT EXISTS**
/// a propósito, y se llama tanto desde onCreate como desde onUpgrade. Así, sin
/// importar en qué versión vieja se haya quedado un dispositivo (incluso una
/// con solo la tabla `categorias`, de las primeras versiones de la app), al
/// abrir la base siempre terminan existiendo todas las tablas actuales. Esto
/// evita el error "no such table" que ocurre si onUpgrade solo asume que las
/// tablas nuevas ya existen.
class DatabaseHelper {
  static Database? _database;
  static Completer<void>? _initCompleter;

  /// Versión del esquema. Súbela cada vez que agregues una tabla o columna,
  /// y agrega el paso correspondiente en `_migrarColumnas` si es una columna
  /// nueva en una tabla que ya existía (CREATE TABLE IF NOT EXISTS no altera
  /// tablas existentes con forma vieja).
  ///
  /// NOTA: se subió de 2 a 3 porque un intento anterior de migración pudo
  /// quedar marcado como "completado" (sqflite guarda la versión al salir
  /// de onUpgrade sin error, aunque algún paso interno haya fallado y sido
  /// capturado por un try/catch) sin haber creado realmente las tablas. Si
  /// vuelve a pasar algo así, la solución siempre es subir este número.
  /// v4: el usuario demo pasó de id='demo-user-1' (string arbitrario) a un
  /// UUID válido, necesario para sincronizar contra usuarios.id (UUID) en
  /// la nube. _migrarColumnas corrige instalaciones existentes.
  static const int _version = 14;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return _database!;
    }
    _initCompleter = Completer<void>();
    try {
      _database = await _inicializar();
    } finally {
      _initCompleter!.complete();
      _initCompleter = null;
    }
    return _database!;
  }

  static Future<Database> _inicializar() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'closi.db');

    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await _crearEsquema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _crearEsquema(db);
        await _migrarColumnas(db, oldVersion);
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  static Future<void> _crearEsquema(Database db) async {
    // ============================================
    // USUARIO (sesión local del dueño del dispositivo)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuario (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        email TEXT,
        telefono TEXT,
        foto_url TEXT,
        password_hash TEXT,
        rol TEXT NOT NULL DEFAULT 'cliente',
        token_sesion TEXT,
        fecha_registro TEXT,
        ultima_sincronizacion TEXT
      )
    ''');

    // ============================================
    // CATEGORIAS (caché de solo lectura; maestro vive en la nube)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categorias (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        icono TEXT,
        color TEXT,
        orden INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1
      )
    ''');

    // ============================================
    // NEGOCIOS PROPIOS (administrados por el usuario, completos y editables)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS negocios_propios (
        id TEXT PRIMARY KEY,
        categoria_id TEXT NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        direccion TEXT,
        telefono TEXT,
        whatsapp TEXT,
        email TEXT,
        sitio_web TEXT,
        redes_sociales TEXT,
        horario TEXT,
        metodo_pago TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        estado TEXT DEFAULT 'pendiente',
        plan_suscripcion TEXT,
        fecha_expiracion_plan TEXT,
        creado_en TEXT,
        actualizado_en TEXT,
        estado_sync TEXT DEFAULT 'pendiente',
        FOREIGN KEY (categoria_id) REFERENCES categorias(id)
      )
    ''');

    // ============================================
    // NEGOCIOS CACHE (solo lectura, negocios cercanos para consulta offline)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS negocios_cache (
        id TEXT PRIMARY KEY,
        categoria_id TEXT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        direccion TEXT,
        telefono TEXT,
        whatsapp TEXT,
        email TEXT,
        sitio_web TEXT,
        redes_sociales TEXT,
        horario TEXT,
        metodo_pago TEXT,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        calificacion_promedio REAL,
        total_resenas INTEGER DEFAULT 0,
        es_destacado INTEGER DEFAULT 0,
        thumbnail_local TEXT,
        ultimo_acceso TEXT,
        ultima_sincronizacion TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_negocios_cache_lat_lon ON negocios_cache(lat, lon)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_negocios_cache_ultimo_acceso ON negocios_cache(ultimo_acceso)');

    // ============================================
    // PRODUCTOS Y SERVICIOS (del negocio propio, editables)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS productos_servicios (
        id TEXT PRIMARY KEY,
        negocio_id TEXT NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        precio REAL,
        disponible INTEGER DEFAULT 1,
        foto_local TEXT,
        creado_en TEXT,
        actualizado_en TEXT,
        estado_sync TEXT DEFAULT 'pendiente',
        FOREIGN KEY (negocio_id) REFERENCES negocios_propios(id) ON DELETE CASCADE
      )
    ''');

    // ============================================
    // FAVORITOS (del usuario, sobre negocios propios o cacheados)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favoritos (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        negocio_id TEXT NOT NULL,
        fecha TEXT,
        estado_sync TEXT DEFAULT 'pendiente'
      )
    ''');

    // ============================================
    // CALIFICACIONES (una por usuario por negocio)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calificaciones (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        negocio_id TEXT NOT NULL,
        calificacion INTEGER DEFAULT 0,
        fecha TEXT,
        estado_sync TEXT DEFAULT 'pendiente',
        UNIQUE(usuario_id, negocio_id)
      )
    ''');

    // ============================================
    // OPINIONES (múltiples por usuario por negocio)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS opiniones (
        id TEXT PRIMARY KEY,
        usuario_id TEXT NOT NULL,
        negocio_id TEXT NOT NULL,
        comentario TEXT,
        anonimo INTEGER DEFAULT 0,
        fecha TEXT,
        nombre_usuario TEXT,
        estado_sync TEXT DEFAULT 'pendiente'
      )
    ''');
    // ============================================
    // CONFIGURACION APP (clave/valor)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS config_app (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    // ============================================
    // CONFIGURACION MAPA (clave/valor)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS config_mapa (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    // ============================================
    // COLA DE SINCRONIZACION (offline-first)
    // ============================================
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cola_sincronizacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tabla TEXT NOT NULL,
        registro_id TEXT NOT NULL,
        operacion TEXT NOT NULL,
        payload TEXT,
        intentos INTEGER DEFAULT 0,
        fecha_creacion TEXT,
        ultimo_intento TEXT,
        error TEXT
      )
    ''');
  }

  /// Agrega columnas nuevas a tablas que puedan haber quedado con forma
  /// vieja en dispositivos que ya tenían la app instalada. Cada ALTER está
  /// protegido individualmente porque SQLite no soporta "ADD COLUMN IF NOT
  /// EXISTS": si la columna ya existe (instalación limpia reciente), se
  /// ignora el error en vez de tumbar el arranque.
  static Future<void> _migrarColumnas(Database db, int oldVersion) async {
    try {
      await db.execute(
          'ALTER TABLE negocios_cache ADD COLUMN es_destacado INTEGER DEFAULT 0');
    } catch (_) {
      // La columna ya existe (o la tabla se acaba de crear con ella ya
      // incluida vía _crearEsquema); nada que hacer.
    }

    if (oldVersion < 5) {
      for (final col in ['whatsapp', 'email']) {
        try {
          await db.execute('ALTER TABLE negocios_propios ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }

    if (oldVersion < 6) {
      for (final col in ['sitio_web', 'redes_sociales']) {
        try {
          await db.execute('ALTER TABLE negocios_propios ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }

    if (oldVersion < 7) {
      for (final col in ['whatsapp', 'email', 'sitio_web', 'redes_sociales']) {
        try {
          await db.execute('ALTER TABLE negocios_cache ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }

    if (oldVersion < 8) {
      for (final col in ['nombre_usuario', 'anonimo']) {
        try {
          await db.execute('ALTER TABLE resenas ADD COLUMN $col TEXT');
        } catch (_) {}
      }
    }

    if (oldVersion < 9) {
      // Migrar datos de resenas → calificaciones (solo filas CON calificacion > 0)
      await db.execute('''
        INSERT OR IGNORE INTO calificaciones (id, usuario_id, negocio_id, calificacion, fecha, estado_sync)
        SELECT id, usuario_id, referencia_id, calificacion, fecha, estado_sync
        FROM resenas
        WHERE tipo = 'negocio' AND calificacion > 0
      ''');
      // Migrar datos de resenas → opiniones (solo filas CON comentario)
      await db.execute('''
        INSERT OR IGNORE INTO opiniones (id, usuario_id, negocio_id, comentario, anonimo, fecha, nombre_usuario, estado_sync)
        SELECT id, usuario_id, referencia_id, comentario,
               CASE WHEN anonimo = '1' OR anonimo = 1 THEN 1 ELSE 0 END,
               fecha, nombre_usuario, estado_sync
        FROM resenas
        WHERE tipo = 'negocio' AND comentario IS NOT NULL AND comentario != ''
      ''');
      // Limpiar tabla legacy
      try { await db.execute('DROP TABLE IF EXISTS resenas'); } catch (_) {}
    }

    if (oldVersion < 10) {
      try { await db.execute("ALTER TABLE usuario ADD COLUMN rol TEXT NOT NULL DEFAULT 'cliente'"); } catch (_) {}
    }

    if (oldVersion < 11) {
      for (final col in ['whatsapp', 'email', 'sitio_web', 'redes_sociales', 'metodo_pago']) {
        try { await db.execute('ALTER TABLE negocios_propios ADD COLUMN $col TEXT'); } catch (_) {}
      }
      try { await db.execute('ALTER TABLE negocios_cache ADD COLUMN metodo_pago TEXT'); } catch (_) {}
    }

    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE usuario ADD COLUMN password_hash TEXT'); } catch (_) {}
    }

    if (oldVersion < 14) {
      try { await db.execute('ALTER TABLE usuario ADD COLUMN foto_url TEXT'); } catch (_) {}
    }
  }

  // ==================================================
  // Utilidades genéricas
  // ==================================================
  static Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    final db = await database;
    return await db.query('categorias', orderBy: 'orden ASC');
  }

  /// Borra toda la base local. Útil para logout o "borrar caché".
  static Future<void> reiniciar() async {
    final db = await database;
    final tablas = [
      'usuario', 'negocios_propios', 'negocios_cache', 'productos_servicios',
      'favoritos', 'calificaciones', 'opiniones', 'cola_sincronizacion',
      // 'categorias', 'config_app', 'config_mapa' se preservan intencionalmente
    ];
    for (final t in tablas) {
      await db.delete(t);
    }
  }
}
