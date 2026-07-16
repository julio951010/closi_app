-- ============================================================
-- Closi — Esquema de base de datos en la nube (PostgreSQL / Supabase)
-- Contiene todos los datos globales del directorio.
-- Durante desarrollo: Postgres local. En producción: Supabase.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabla legacy resenas eliminada (reemplazada por calificaciones + opiniones)
DROP TABLE IF EXISTS resenas CASCADE;

-- ============================================
-- USUARIOS
-- ============================================
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL,
  email TEXT UNIQUE,
  telefono TEXT,
  password_hash TEXT,
  rol TEXT NOT NULL DEFAULT 'cliente',    -- cliente | propietario | admin
  estado_cuenta TEXT DEFAULT 'activo',
  creado_en TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- CATEGORIAS (maestro, fuente de verdad)
-- IMPORTANTE: id es TEXT (slug), NO uuid_generate_v4(). Debe coincidir
-- exactamente con los slugs sembrados en el SQLite local
-- (ver DatabaseHelper._categoriasSeed) para que negocios.categoria_id
-- pueda sincronizarse sin traducción.
-- ============================================
CREATE TABLE IF NOT EXISTS categorias (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  icono TEXT,
  color TEXT,
  orden INTEGER DEFAULT 0,
  version INTEGER DEFAULT 1
);

INSERT INTO categorias (id, nombre, icono, color, orden) VALUES
  ('restaurante', 'Restaurante', 'restaurant', '#E65100', 1),
  ('cafeteria', 'Cafetería', 'coffee', '#6D4C41', 2),
  ('farmacia', 'Farmacia', 'local_pharmacy', '#00C853', 3),
  ('tienda', 'Tienda', 'shopping_bag', '#FF6F00', 4),
  ('taller', 'Taller', 'build', '#607D8B', 5),
  ('hotel', 'Hotel', 'hotel', '#2962FF', 6),
  ('hospital', 'Hospital', 'local_hospital', '#D50000', 7),
  ('banco', 'Banco', 'account_balance', '#6200EA', 8),
  ('wifi', 'WiFi', 'wifi', '#00BCD4', 9),
  ('transporte', 'Transporte', 'directions_bus', '#FF5722', 10),
  ('cultura', 'Cultura', 'theater_comedy', '#8E24AA', 11),
  ('deporte', 'Deporte', 'fitness_center', '#43A047', 12)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- NEGOCIOS (todos, con geolocalización PostGIS)
-- ============================================
CREATE TABLE IF NOT EXISTS negocios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  propietario_id UUID REFERENCES usuarios(id),
  categoria_id TEXT REFERENCES categorias(id),
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
  ubicacion GEOGRAPHY(POINT, 4326) NOT NULL,
  estado TEXT DEFAULT 'pendiente',        -- pendiente | aprobado | rechazado
  es_destacado BOOLEAN DEFAULT FALSE,
  plan_suscripcion TEXT,
  fecha_expiracion_plan TIMESTAMPTZ,
  calificacion_promedio NUMERIC(2,1) DEFAULT 0,
  total_resenas INTEGER DEFAULT 0,
  creado_en TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_negocios_ubicacion ON negocios USING GIST(ubicacion);
CREATE INDEX IF NOT EXISTS idx_negocios_categoria ON negocios(categoria_id);
CREATE INDEX IF NOT EXISTS idx_negocios_estado ON negocios(estado);

-- ============================================
-- PRODUCTOS Y SERVICIOS
-- ============================================
CREATE TABLE IF NOT EXISTS productos_servicios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  precio NUMERIC(10,2),
  disponible BOOLEAN DEFAULT true,
  creado_en TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- FOTOS (Supabase Storage, se referencia por URL)
-- ============================================
CREATE TABLE IF NOT EXISTS fotos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo TEXT NOT NULL,                     -- negocio | producto
  referencia_id UUID NOT NULL,
  url TEXT NOT NULL,
  url_thumbnail TEXT,                     -- versión comprimida, usada en la caché local
  orden INTEGER DEFAULT 0,
  creado_en TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- FAVORITOS (para que persistan si el usuario cambia de dispositivo)
-- ============================================
CREATE TABLE IF NOT EXISTS favoritos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID REFERENCES usuarios(id) ON DELETE CASCADE,
  negocio_id UUID REFERENCES negocios(id) ON DELETE CASCADE,
  creado_en TIMESTAMPTZ DEFAULT now(),
  UNIQUE (usuario_id, negocio_id)
);

-- ============================================
-- CALIFICACIONES (una por usuario por negocio, se reemplaza al recalificar)
-- ============================================
CREATE TABLE IF NOT EXISTS calificaciones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID REFERENCES usuarios(id),
  negocio_id UUID NOT NULL REFERENCES negocios(id) ON DELETE CASCADE,
  calificacion SMALLINT NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
  creado_en TIMESTAMPTZ DEFAULT now(),
  UNIQUE (usuario_id, negocio_id)
);
CREATE INDEX IF NOT EXISTS idx_calificaciones_negocio ON calificaciones(negocio_id);

-- ============================================
-- OPINIONES (múltiples por usuario por negocio)
-- ============================================
CREATE TABLE IF NOT EXISTS opiniones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id UUID REFERENCES usuarios(id),
  negocio_id UUID NOT NULL REFERENCES negocios(id) ON DELETE CASCADE,
  comentario TEXT NOT NULL,
  anonimo BOOLEAN DEFAULT false,
  creado_en TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_opiniones_negocio ON opiniones(negocio_id);
CREATE INDEX IF NOT EXISTS idx_opiniones_usuario ON opiniones(usuario_id);

-- ============================================
-- SUSCRIPCIONES
-- ============================================
CREATE TABLE IF NOT EXISTS suscripciones (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  negocio_id UUID REFERENCES negocios(id),
  plan TEXT NOT NULL,
  estado TEXT DEFAULT 'activa',           -- activa | vencida | cancelada
  fecha_inicio TIMESTAMPTZ DEFAULT now(),
  fecha_vencimiento TIMESTAMPTZ,
  monto NUMERIC(10,2)
);

-- ============================================
-- NOTIFICACIONES ADMIN (aprobación de negocios nuevos, reportes, etc.)
-- ============================================
CREATE TABLE IF NOT EXISTS notificaciones_admin (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tipo TEXT NOT NULL,                     -- negocio_pendiente | reporte | etc.
  referencia_id UUID,
  mensaje TEXT,
  leida BOOLEAN DEFAULT false,
  creado_en TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- TRIGGER: mantiene calificacion_promedio y total_resenas al día
-- en `negocios` cada vez que se inserta/borra/actualiza una calificación.
-- ============================================================
CREATE OR REPLACE FUNCTION actualizar_calificacion_negocio()
RETURNS TRIGGER AS $$
DECLARE
  target_id UUID;
BEGIN
  target_id := COALESCE(NEW.negocio_id, OLD.negocio_id);

  UPDATE negocios
  SET calificacion_promedio = COALESCE((
        SELECT ROUND(AVG(calificacion)::numeric, 1)
        FROM calificaciones WHERE negocio_id = target_id
      ), 0),
      total_resenas = (
        SELECT COUNT(*) FROM calificaciones WHERE negocio_id = target_id
      )
  WHERE id = target_id;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_actualizar_calificacion ON calificaciones;
CREATE TRIGGER trg_actualizar_calificacion
AFTER INSERT OR UPDATE OR DELETE ON calificaciones
FOR EACH ROW EXECUTE FUNCTION actualizar_calificacion_negocio();

-- ============================================================
-- CONSULTA DE REFERENCIA: negocios cercanos para poblar negocios_cache
-- desde el cliente Flutter (paginada, priorizando cercanía y calificación).
-- Reemplazar $lon, $lat, $radio_metros, $pagina por parámetros reales.
-- ============================================================
-- SELECT id, nombre, categoria_id, direccion, telefono, horario, descripcion,
--        ST_Y(ubicacion::geometry) AS lat, ST_X(ubicacion::geometry) AS lon,
--        calificacion_promedio, total_resenas
-- FROM negocios
-- WHERE estado = 'aprobado'
--   AND ST_DWithin(ubicacion, ST_MakePoint($lon, $lat)::geography, $radio_metros)
-- ORDER BY calificacion_promedio DESC, ST_Distance(ubicacion, ST_MakePoint($lon, $lat)::geography) ASC
-- LIMIT 100 OFFSET $pagina;

-- ============================================================
-- ADMIN SEED (contraseña: JulioCesar1.)
-- ============================================================
INSERT INTO usuarios (id, nombre, email, password_hash, rol) VALUES
  ('a0000001-0000-0000-0000-000000000001', 'Julio César', 'juliocesar951010@gmail.com',
   '$2a$10$/2L.ZCCcu58NFhAVdv83YepEB2oguvcycuosSibLd9524HlIlbrWa', 'admin')
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- MIGRACIÓN v4→v5 (email, whatsapp)
-- ============================================================
-- ALTER TABLE negocios ADD COLUMN IF NOT EXISTS whatsapp TEXT;
-- ALTER TABLE negocios ADD COLUMN IF NOT EXISTS email TEXT;
--
-- MIGRACIÓN v5→v6 (sitio_web, redes_sociales)
-- ============================================================
-- ALTER TABLE negocios ADD COLUMN IF NOT EXISTS sitio_web TEXT;
-- ALTER TABLE negocios ADD COLUMN IF NOT EXISTS redes_sociales TEXT;
