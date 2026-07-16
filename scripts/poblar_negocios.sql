-- =============================================================================
-- Closi App — Poblar la base de datos PostgreSQL con datos reales de La Habana
-- =============================================================================
-- Ejecutar: psql -U postgres -d closi_db -f poblar_negocios.sql
-- O desde pgAdmin: abrir este archivo y ejecutar.
-- =============================================================================
-- SIN transacción explícita para que cada error se vea individualmente.

-- ---------------------------------------------------------------------------
-- 1. ESQUEMA: asegurar que las tablas existen
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categorias (
  id TEXT PRIMARY KEY,
  nombre TEXT NOT NULL,
  icono TEXT,
  color TEXT,
  orden INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre TEXT NOT NULL,
  email TEXT,
  telefono TEXT,
  creado_en TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS negocios (
  id TEXT PRIMARY KEY,
  propietario_id UUID REFERENCES usuarios(id),
  categoria_id TEXT NOT NULL REFERENCES categorias(id),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  direccion TEXT,
  telefono TEXT,
  whatsapp TEXT,
  email TEXT,
  sitio_web TEXT,
  redes_sociales TEXT,
  horario TEXT,
  ubicacion GEOGRAPHY(POINT) NOT NULL,
  calificacion_promedio REAL DEFAULT 0,
  total_resenas INTEGER DEFAULT 0,
  es_destacado BOOLEAN DEFAULT false,
  estado TEXT DEFAULT 'aprobado',
  creado_en TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- Agrega columnas que pueden faltar si la tabla ya existía sin ellas
ALTER TABLE negocios ADD COLUMN IF NOT EXISTS calificacion_promedio REAL DEFAULT 0;
ALTER TABLE negocios ADD COLUMN IF NOT EXISTS total_resenas INTEGER DEFAULT 0;
ALTER TABLE negocios ADD COLUMN IF NOT EXISTS es_destacado BOOLEAN DEFAULT false;
-- Tabla legacy resenas eliminada en v9 (reemplazada por calificaciones + opiniones)
DROP TABLE IF EXISTS resenas;

CREATE TABLE IF NOT EXISTS favoritos (
  id SERIAL PRIMARY KEY,
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  negocio_id UUID NOT NULL REFERENCES negocios(id),
  creado_en TIMESTAMPTZ DEFAULT now(),
  UNIQUE(usuario_id, negocio_id)
);

CREATE TABLE IF NOT EXISTS calificaciones (
  id TEXT PRIMARY KEY,
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  negocio_id UUID NOT NULL REFERENCES negocios(id),
  calificacion INTEGER DEFAULT 0,
  creado_en TIMESTAMPTZ DEFAULT now(),
  UNIQUE (usuario_id, negocio_id)
);

CREATE TABLE IF NOT EXISTS opiniones (
  id TEXT PRIMARY KEY,
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  negocio_id UUID NOT NULL REFERENCES negocios(id),
  comentario TEXT NOT NULL,
  anonimo BOOLEAN DEFAULT false,
  creado_en TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS productos_servicios (
  id TEXT PRIMARY KEY,
  negocio_id UUID NOT NULL REFERENCES negocios(id),
  nombre TEXT NOT NULL,
  descripcion TEXT,
  precio REAL,
  disponible BOOLEAN DEFAULT true,
  creado_en TIMESTAMPTZ DEFAULT now(),
  actualizado_en TIMESTAMPTZ DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- 2. CATEGORÍAS (12 categorías que usa la app)
-- ---------------------------------------------------------------------------

INSERT INTO categorias (id, nombre, icono, color, orden) VALUES
  ('restaurante', 'Restaurante', 'restaurant', '#E65100', 1),
  ('cafeteria',   'Cafetería',   'coffee',     '#6D4C41', 2),
  ('farmacia',    'Farmacia',    'local_pharmacy', '#00C853', 3),
  ('tienda',      'Tienda',      'shopping_bag',   '#FF6F00', 4),
  ('taller',      'Taller',      'build',          '#607D8B', 5),
  ('hotel',       'Hotel',       'hotel',           '#2962FF', 6),
  ('hospital',    'Hospital',    'local_hospital',  '#D50000', 7),
  ('banco',       'Banco',       'account_balance', '#6200EA', 8),
  ('wifi',        'WiFi',        'wifi',            '#00BCD4', 9),
  ('transporte',  'Transporte',  'directions_bus',  '#FF5722', 10),
  ('cultura',     'Cultura',     'theater_comedy',  '#8E24AA', 11),
  ('deporte',     'Deporte',     'fitness_center',  '#43A047', 12)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. USUARIO por defecto
-- ---------------------------------------------------------------------------

INSERT INTO usuarios (id, nombre, email, telefono) VALUES
  ('00000000-0000-4000-8000-000000000001', 'Julio César', 'julio@email.cu', '+53 5 123-4567')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. NEGOCIOS — 24 negocios reales distribuidos por La Habana
-- ---------------------------------------------------------------------------

INSERT INTO negocios (id, propietario_id, categoria_id, nombre, descripcion, direccion, telefono, whatsapp, horario, ubicacion, calificacion_promedio, total_resenas, es_destacado) VALUES
-- ======================= RESTAURANTE =======================
(
  'a0000001-0000-4000-a000-000000000001', NULL, 'restaurante',
  'La Cocina de Lilliam',
  'Auténtica cocina cubana e internacional en una casa colonial restaurada. Uno de los paladares más reconocidos de La Habana.',
  'Calle 48 No. 1311 entre 13 y 15, Playa',
  '+53 7 209-6524', '+53 5 280-1234',
  '12:00 – 23:00',
  ST_MakePoint(-82.4460, 23.0920)::geography,
  4.7, 312, true
),
(
  'a0000002-0000-4000-a000-000000000002', NULL, 'restaurante',
  'El Chanchullero',
  'Cocina callejera cubana con un toque moderno. Famoso por sus sándwiches cubanos y la pizza chanchullera.',
  'Calle Teniente Rey 459 e/ Aguacate y Compostela, La Habana Vieja',
  '+53 7 862-7440', '+53 5 314-5678',
  '11:00 – 22:00',
  ST_MakePoint(-82.3495, 23.1395)::geography,
  4.5, 198, true
),

-- ======================= CAFETERÍA =======================
(
  'a0000003-0000-4000-a000-000000000003', NULL, 'cafeteria',
  'Heladería Coppelia',
  'La heladería más emblemática de Cuba, icono cultural del Vedado. Más de 50 sabores artesanales.',
  'Calle L e/ 23 y 25, Vedado',
  '+53 7 832-6214', NULL,
  '10:00 – 21:00',
  ST_MakePoint(-82.3810, 23.1450)::geography,
  4.3, 567, true
),
(
  'a0000004-0000-4000-a000-000000000004', NULL, 'cafeteria',
  'Café O''Reilly',
  'Cafetería de especialidad en pleno centro histórico. Café orgánico de montaña y repostería artesanal.',
  'Calle O''Reilly 302 e/ Habana y Compostela, La Habana Vieja',
  '+53 7 861-9876', '+53 5 123-9876',
  '8:00 – 20:00',
  ST_MakePoint(-82.3518, 23.1382)::geography,
  4.6, 143, false
),

-- ======================= FARMACIA =======================
(
  'a0000005-0000-4000-a000-000000000005', NULL, 'farmacia',
  'Farmacia Sarrá',
  'Farmacia tradicional fundada en 1885. Conserva su mobiliario original de cedro y cristales biselados. Medicinas naturales y homeopatía.',
  'Calle Obispo 451 e/ Aguacate y Compostela, La Habana Vieja',
  '+53 7 862-9583', NULL,
  '8:30 – 17:30',
  ST_MakePoint(-82.3505, 23.1380)::geography,
  4.4, 89, false
),
(
  'a0000006-0000-4000-a000-000000000006', NULL, 'farmacia',
  'Farmacia Internacional 24h',
  'Farmacia con servicio 24 horas. Amplio surtido de medicamentos importados y nacionales. Atención farmacéutica personalizada.',
  'Av. 23 No. 201 e/ L y M, Vedado',
  '+53 7 832-4567', '+53 5 456-7890',
  'Abierto 24 horas',
  ST_MakePoint(-82.3856, 23.1234)::geography,
  4.2, 76, true
),

-- ======================= TIENDA =======================
(
  'a0000007-0000-4000-a000-000000000007', NULL, 'tienda',
  'Mercado 4 Caminos',
  'El mercado más grande de La Habana. Alimentos frescos, productos de limpieza, carnes y vegetales. Precios mayoristas.',
  'Av. 51 y Av. 74, Marianao',
  '+53 7 260-3030', NULL,
  '7:00 – 18:00',
  ST_MakePoint(-82.4290, 23.0750)::geography,
  3.8, 234, false
),
(
  'a0000008-0000-4000-a000-000000000008', NULL, 'tienda',
  'Tienda Caracol Miramar',
  'Centro comercial con tiendas de ropa, electrónica, perfumes y souvenirs. Acepta MLC y tarjetas.',
  '5ta Av. e/ 78 y 80, Miramar',
  '+53 7 204-5678', NULL,
  '9:00 – 19:00',
  ST_MakePoint(-82.4060, 23.1170)::geography,
  4.0, 145, true
),

-- ======================= TALLER =======================
(
  'a0000009-0000-4000-a000-000000000009', NULL, 'taller',
  'Taller San Cristóbal',
  'Taller mecánico especializado en autos clásicos americanos. Diagnóstico computarizado y reparación de motores V8.',
  'Calle 100 No. 3102, Boyeros',
  '+53 7 645-7890', '+53 5 789-0123',
  '7:00 – 17:00',
  ST_MakePoint(-82.3456, 23.0987)::geography,
  4.1, 67, false
),
(
  'a0000010-0000-4000-a000-000000000010', NULL, 'taller',
  'ElectroTaller Habana',
  'Reparación de electrodomésticos, aires acondicionados y refrigeración. Servicio a domicilio.',
  'Calle 12 No. 105 e/ 1ra y 3ra, Playa',
  '+53 7 203-4567', '+53 5 234-5678',
  '8:00 – 17:00',
  ST_MakePoint(-82.4520, 23.0890)::geography,
  4.3, 45, false
),

-- ======================= HOTEL =======================
(
  'a0000011-0000-4000-a000-000000000011', NULL, 'hotel',
  'Hotel Nacional de Cuba',
  'Hotel icónico del Vedado con vista al Malecón. Piscinas, spa, restaurantes, bares y el legendario Salón de la Fama.',
  'Calle 21 y O, Vedado',
  '+53 7 836-3564', '+53 5 876-5432',
  'Check-in 24 horas',
  ST_MakePoint(-82.3809, 23.1433)::geography,
  4.7, 512, true
),
(
  'a0000012-0000-4000-a000-000000000012', NULL, 'hotel',
  'Hotel Sevilla',
  'Hotel histórico en el centro de La Habana. Arquitectura neocolonial, azotea con piscina y vistas panorámicas.',
  'Trocadero 55 e/ Zulueta y Prado, La Habana Vieja',
  '+53 7 860-8160', NULL,
  'Check-in 15:00',
  ST_MakePoint(-82.3575, 23.1375)::geography,
  4.5, 389, true
),

-- ======================= HOSPITAL =======================
(
  'a0000013-0000-4000-a000-000000000013', NULL, 'hospital',
  'Hospital Hermanos Ameijeiras',
  'Hospital clínico-quirúrgico de referencia nacional. Especialidades, cirugía cardiovascular, trasplantes y emergencias.',
  'Calle San Lázaro 701 e/ Belascoaín y Marqués González, Centro Habana',
  '+53 7 876-1000', NULL,
  'Emergencias 24 horas',
  ST_MakePoint(-82.3680, 23.1260)::geography,
  4.0, 56, false
),
(
  'a0000014-0000-4000-a000-000000000014', NULL, 'hospital',
  'Hospital Pediátrico Juan Manuel Márquez',
  'Hospital infantil de referencia. Pediatría, neonatología, cirugía infantil y terapia intensiva.',
  'Av. 31 e/ 76 y 80, Marianao',
  '+53 7 260-6811', NULL,
  'Emergencias 24 horas',
  ST_MakePoint(-82.4370, 23.0720)::geography,
  3.9, 34, false
),

-- ======================= BANCO =======================
(
  'a0000015-0000-4000-a000-000000000015', NULL, 'banco',
  'Banco Central de Cuba — Sucursal Obispo',
  'Sucursal bancaria con servicios de cambio de divisa, cuentas corrientes y de ahorro, transferencias nacionales.',
  'Calle Obispo 302 e/ Habana y Compostela, La Habana Vieja',
  '+53 7 868-4444', NULL,
  '8:30 – 15:30',
  ST_MakePoint(-82.3510, 23.1385)::geography,
  3.5, 23, false
),
(
  'a0000016-0000-4000-a000-000000000016', NULL, 'banco',
  'Banco de Crédito y Comercio — Sucursal Vedado',
  'Banco comercial con servicios empresariales y personales. Cajeros automáticos 24h.',
  'Calle 23 No. 150 e/ L y M, Vedado',
  '+53 7 832-7890', NULL,
  '8:30 – 15:30',
  ST_MakePoint(-82.3830, 23.1440)::geography,
  3.6, 18, false
),

-- ======================= WiFi =======================
(
  'a0000017-0000-4000-a000-000000000017', NULL, 'wifi',
  'Zona WiFi Parque Central',
  'Zona WiFi pública con acceso a internet por recarga Nauta. Amplia cobertura, bancos cercanos para sentarse.',
  'Parque Central, La Habana Vieja',
  NULL, NULL,
  'Acceso 24 horas',
  ST_MakePoint(-82.3589, 23.1378)::geography,
  3.5, 23, true
),
(
  'a0000018-0000-4000-a000-000000000018', NULL, 'wifi',
  'Zona WiFi La Rampa',
  'Zona WiFi pública en el corazón del Vedado. Cerca de cines, restaurantes y hoteles. Bancos en la sombra.',
  'Calle 23 e/ N y O, Vedado (La Rampa)',
  NULL, NULL,
  'Acceso 24 horas',
  ST_MakePoint(-82.3790, 23.1455)::geography,
  3.4, 15, false
),

-- ======================= TRANSPORTE =======================
(
  'a0000019-0000-4000-a000-000000000019', NULL, 'transporte',
  'Terminal de Ómnibus Nacionales',
  'Terminal principal de ómnibus interprovinciales. Conexiones a todas las provincias del país. Taquillas y sala de espera.',
  'Av. de la Independencia, Nuevo Vedado',
  '+53 7 870-3399', NULL,
  '6:00 – 22:00',
  ST_MakePoint(-82.3700, 23.1150)::geography,
  3.2, 67, false
),
(
  'a0000020-0000-4000-a000-000000000020', NULL, 'transporte',
  'Estación Central de Ferrocarriles',
  'Estación de trenes histórica con servicios a varias provincias. Trenes regulares y especiales.',
  'Av. de Bélgica e/ Arsenal y Desamparados, La Habana Vieja',
  '+53 7 862-1968', NULL,
  '5:00 – 21:00',
  ST_MakePoint(-82.3550, 23.1330)::geography,
  3.1, 42, false
),

-- ======================= CULTURA =======================
(
  'a0000021-0000-4000-a000-000000000021', NULL, 'cultura',
  'Museo de Bellas Artes',
  'El museo de arte más importante de Cuba. Colección permanente de arte cubano e internacional. Exposiciones temporales.',
  'Calle Trocadero e/ Zulueta y Monserrate, La Habana Vieja',
  '+53 7 862-5140', NULL,
  '9:00 – 17:00 (cerrado lunes)',
  ST_MakePoint(-82.3570, 23.1370)::geography,
  4.8, 234, true
),
(
  'a0000022-0000-4000-a000-000000000022', NULL, 'cultura',
  'Gran Teatro de La Habana Alicia Alonso',
  'Teatro histórico, sede del Ballet Nacional de Cuba. Arquitectura neobarroca, programación de ópera, danza y música sinfónica.',
  'Paseo de Martí (Prado) 458, La Habana Vieja',
  '+53 7 861-3077', NULL,
  'Taquilla: 10:00 – 18:00',
  ST_MakePoint(-82.3580, 23.1365)::geography,
  4.9, 456, true
),

-- ======================= DEPORTE =======================
(
  'a0000023-0000-4000-a000-000000000023', NULL, 'deporte',
  'Estadio Latinoamericano',
  'El estadio de béisbol más grande de Cuba, casa del equipo Industriales. Capacidad para 55 000 espectadores.',
  'Calle Pedro Pérez 302, Cerro',
  '+53 7 870-1234', NULL,
  'Taquilla: 9:00 – 17:00 (días de juego)',
  ST_MakePoint(-82.3789, 23.1178)::geography,
  4.3, 89, true
),
(
  'a0000024-0000-4000-a000-000000000024', NULL, 'deporte',
  'Ciudad Deportiva',
  'Complejo deportivo multidisciplinario. Gimnasios, canchas de baloncesto, voleibol, boxeo y piscina olímpica.',
  'Vía Blanca y Av. Rancho Boyeros, Cerro',
  '+53 7 645-9876', NULL,
  '6:00 – 20:00',
  ST_MakePoint(-82.3650, 23.1070)::geography,
  4.0, 56, false
) ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. PRODUCTOS/SERVICIOS de muestra
-- ---------------------------------------------------------------------------

INSERT INTO productos_servicios (id, negocio_id, nombre, descripcion, precio, disponible) VALUES
  ('b0000001-0000-4000-b000-000000000001', 'a0000001-0000-4000-a000-000000000001', 'Ropa Vieja', 'Carne de res desmenuzada en salsa de tomate y especias, servida con arroz blanco, frijoles negros y plátanos maduros.', 450.00, true),
  ('b0000002-0000-4000-b000-000000000002', 'a0000001-0000-4000-a000-000000000001', 'Arroz con Pollo', 'Pollo troceado cocinado con arroz, cerveza, azafrán y vegetales.', 350.00, true),
  ('b0000003-0000-4000-b000-000000000003', 'a0000003-0000-4000-a000-000000000003', 'Mango Split', 'Tres bolas de helado de mango, vainilla y chocolate con sirope y fruta fresca.', 120.00, true),
  ('b0000004-0000-4000-b000-000000000004', 'a0000003-0000-4000-a000-000000000003', 'Sundaé de Guayaba', 'Helado de crema con pasta de guayaba, queso crema y galleta triturada.', 100.00, true),
  ('b0000005-0000-4000-b000-000000000005', 'a0000009-0000-4000-a000-000000000009', 'Diagnóstico computarizado', 'Escaneo completo del motor y sistemas electrónicos con reporte impreso.', 500.00, true),
  ('b0000006-0000-4000-b000-000000000006', 'a0000009-0000-4000-a000-000000000009', 'Cambio de aceite y filtros', 'Incluye aceite sintético 10W-40, filtro de aceite y filtro de aire.', 1200.00, true)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. CALIFICACIONES de muestra
-- ---------------------------------------------------------------------------

INSERT INTO calificaciones (id, usuario_id, negocio_id, calificacion) VALUES
  ('c0000001-0000-4000-c000-000000000001', '00000000-0000-4000-8000-000000000001', 'a0000001-0000-4000-a000-000000000001', 5),
  ('c0000002-0000-4000-c000-000000000002', '00000000-0000-4000-8000-000000000001', 'a0000002-0000-4000-a000-000000000002', 4),
  ('c0000003-0000-4000-c000-000000000003', '00000000-0000-4000-8000-000000000001', 'a0000003-0000-4000-a000-000000000003', 4),
  ('c0000004-0000-4000-c000-000000000004', '00000000-0000-4000-8000-000000000001', 'a0000011-0000-4000-a000-000000000011', 5),
  ('c0000005-0000-4000-c000-000000000005', '00000000-0000-4000-8000-000000000001', 'a0000021-0000-4000-a000-000000000021', 5)
ON CONFLICT (usuario_id, negocio_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6b. OPINIONES de muestra
-- ---------------------------------------------------------------------------

INSERT INTO opiniones (id, usuario_id, negocio_id, comentario, anonimo) VALUES
  ('d0000001-0000-4000-d000-000000000001', '00000000-0000-4000-8000-000000000001', 'a0000001-0000-4000-a000-000000000001', 'Excelente comida y servicio. El ambiente es inigualable. Recomiendo la ropa vieja.', false),
  ('d0000002-0000-4000-d000-000000000002', '00000000-0000-4000-8000-000000000001', 'a0000002-0000-4000-a000-000000000002', 'Los sándwiches cubanos son los mejores de La Habana. Precios accesibles.', false),
  ('d0000003-0000-4000-d000-000000000003', '00000000-0000-4000-8000-000000000001', 'a0000003-0000-4000-a000-000000000003', 'Helado cremoso y económico. Las colas pueden ser largas pero vale la pena.', false),
  ('d0000004-0000-4000-d000-000000000004', '00000000-0000-4000-8000-000000000001', 'a0000011-0000-4000-a000-000000000011', 'Vistas espectaculares al malecón. Instalaciones de lujo, personal atento.', false),
  ('d0000005-0000-4000-d000-000000000005', '00000000-0000-4000-8000-000000000001', 'a0000021-0000-4000-a000-000000000021', 'Colección impresionante de arte cubano. La entrada es muy económica.', false)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. VERIFICACIÓN
-- ---------------------------------------------------------------------------

SELECT '✅ Categorías' AS check, COUNT(*) AS total FROM categorias
UNION ALL
SELECT '✅ Negocios', COUNT(*) FROM negocios
UNION ALL
SELECT '✅ Productos/Servicios', COUNT(*) FROM productos_servicios
UNION ALL
SELECT '✅ Calificaciones', COUNT(*) FROM calificaciones
UNION ALL
SELECT '✅ Opiniones', COUNT(*) FROM opiniones;
