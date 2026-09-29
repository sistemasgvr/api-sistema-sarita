-- =============================================================================
-- 02 PREREQUISITOS BALONES: empresa, sucursal, almacenes, gases, tipos
-- Generado desde LlenadoDatos.xlsx (Empresa/Almacenes/Gases/TiposBalon + Balones)
-- =============================================================================
BEGIN;
SET TIME ZONE 'America/Lima';

-- Empresa
INSERT INTO gen_empresa (ruc, razon_social, nombre_comercial, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT '10175332796', 'OXIGENO SARITA', 'OXIGENO SARITA', 1, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_empresa WHERE ruc = '10175332796');

-- Sucursal
INSERT INTO gen_sucursal (codigo, nombre, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'PRINCIPAL', 'Sucursal Principal', 1, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_sucursal WHERE UPPER(codigo) = UPPER('PRINCIPAL'));

-- Almacenes
INSERT INTO gen_almacen (id_sucursal, nombre, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT s.id, 'ALMACEN LAMBAYEQUE', 1, 1, 1
FROM gen_sucursal s
WHERE UPPER(s.codigo) = UPPER('PRINCIPAL')
  AND NOT EXISTS (
    SELECT 1 FROM gen_almacen a WHERE UPPER(TRIM(a.nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE'))
  );

INSERT INTO gen_almacen (id_sucursal, nombre, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT s.id, 'ALMACEN PRINCIPAL', 1, 1, 1
FROM gen_sucursal s
WHERE UPPER(s.codigo) = UPPER('PRINCIPAL')
  AND NOT EXISTS (
    SELECT 1 FROM gen_almacen a WHERE UPPER(TRIM(a.nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL'))
  );

-- Productos gas (es_gas = TRUE)
INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-ACE-ESP', 'ACETILENO ESPECIAL', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESPECIAL'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-ACE-ESP');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-ACE-EST', 'ACETILENO ESTANDAR', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-ACE-EST');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-AIRE-COMPRIMIDO', 'AIRE COMPRIMIDO', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('AIRE COMPRIMIDO'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-AIRE-COMPRIMIDO');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-ARGON', 'ARGON', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ARGON'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-ARGON');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-CO2', 'DIÓXIDO DE CARBONO', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-CO2');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-ETILENO', 'ETILENO', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ETILENO'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-ETILENO');

-- Propano: producto de stock (no gas con cilindro en POS)
INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-PROPANO', 'GAS PROPANO', FALSE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE UPPER(TRIM(p.nombre)) = UPPER(TRIM('GAS PROPANO'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-PROPANO');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-NITROGENO', 'NITROGENO', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('NITROGENO'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-NITROGENO');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-OXI-IND', 'OXIGENO INDUSTRIAL', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-OXI-IND');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-OXI-MED', 'OXIGENO MEDICINAL', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO MEDICINAL'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-OXI-MED');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-STARGOLD', 'STARGOLD ESTANDAR', TRUE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (
  SELECT 1 FROM pro_producto p
  WHERE p.es_gas = TRUE AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('STARGOLD ESTANDAR'))
)
AND NOT EXISTS (SELECT 1 FROM pro_producto p2 WHERE p2.codigo = 'GAS-STARGOLD');

-- Tipos de balón
INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno 0 kg',
  p.id,
  0.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno 0 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno 1 - 3 kg',
  p.id,
  3.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno 1 - 3 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno 5 kg',
  p.id,
  5.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno 5 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 1 - 4 kg',
  p.id,
  4.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 1 - 4 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 3.5 - 5 kg',
  p.id,
  5.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 3.5 - 5.5 kg',
  p.id,
  5.5,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5.5 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 4 kg',
  p.id,
  4.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 4 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 6 - 7.5 kg',
  p.id,
  7.5,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 6 - 7.5 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 6 - 8 kg',
  p.id,
  8.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 6 - 8 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 7 - 9 kg',
  p.id,
  9.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 8 - 10 kg',
  p.id,
  10.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Acetileno de 8kg',
  p.id,
  8.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ACETILENO ESPECIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Acetileno de 8kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Argón Estándar 10 m3',
  p.id,
  10.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ARGON'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Argón Estándar 10 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Argón Estándar  3 m3',
  p.id,
  3.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ARGON'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Argón Estándar  3 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Argón Estándar  6 m3',
  p.id,
  6.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ARGON'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Argón Estándar  6 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Dióxido de carbono 13 kg',
  p.id,
  13.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Dióxido de carbono 13 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Dióxido de carbono 25 kg',
  p.id,
  25.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Dióxido de carbono 25 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'DIOXIDO DE CARBONO 3 KG',
  p.id,
  3.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('DIOXIDO DE CARBONO 3 KG'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Dióxido de carbono 30 kg',
  p.id,
  30.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Dióxido de carbono 7 kg',
  p.id,
  7.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Dióxido de carbono 7 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'DIOXIDO DE CARBONO 9 KG',
  p.id,
  9.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('DIOXIDO DE CARBONO 9 KG'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Dioxido de Carbono de 12 kg',
  p.id,
  12.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Dioxido de Carbono de 12 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Etil 10 m³',
  p.id,
  10.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('ETILENO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Etil 10 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Gas Propano 10 kg',
  p.id,
  10.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('GAS PROPANO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Gas Propano 10 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Gas Propano 45 kg',
  p.id,
  45.0,
  7,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('GAS PROPANO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Gas Propano 45 kg'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Nitrógeno 10 m³',
  p.id,
  10.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('NITROGENO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Nitrógeno 10 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Nitrógeno 3 m³',
  p.id,
  3.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('NITROGENO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Nitrógeno 3 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Nitrógeno 6 m³',
  p.id,
  6.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('NITROGENO'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Nitrógeno 6 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 1 m³',
  p.id,
  1.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 1 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxígeno Industrial 10 m³',
  p.id,
  10.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 2 m³',
  p.id,
  2.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 2 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 2.5 m³',
  p.id,
  2.5,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 2.5 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 3 m³',
  p.id,
  3.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 4 m³',
  p.id,
  4.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 4 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxígeno Industrial 6 m³',
  p.id,
  6.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 7 m³',
  p.id,
  7.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 7 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial 8 m³',
  p.id,
  8.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Industrial de 1.5 m3',
  p.id,
  1.5,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Industrial de 1.5 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Medicinal 1 m³',
  p.id,
  1.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO MEDICINAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Medicinal 1 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxigeno Medicinal 1.5 m³',
  p.id,
  1.5,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO MEDICINAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxigeno Medicinal 1.5 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxígeno Medicinal 10 m³',
  p.id,
  10.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO MEDICINAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxígeno Medicinal 3 m³',
  p.id,
  3.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO MEDICINAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxígeno Medicinal 3 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Oxígeno Medicinal 6 m³',
  p.id,
  6.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('OXIGENO MEDICINAL'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Stargold Estandar de 10 m3',
  p.id,
  10.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('STARGOLD ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Stargold Estandar de 3 m3',
  p.id,
  3.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('STARGOLD ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Stargold Estandar de 3 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Stargold Estandar de 6 m3',
  p.id,
  6.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('STARGOLD ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3'))
  )
LIMIT 1;

INSERT INTO bal_tipo_balon (
  nombre, id_gas, capacidad, id_unidad_medida, estado,
  vigencia_ph_anios, id_usuario_creacion, id_usuario_modificacion
)
SELECT
  'Stargold Estandar de 7 m3',
  p.id,
  7.0,
  11,
  1,
  5,
  1,
  1
FROM pro_producto p
WHERE p.es_gas = TRUE
  AND UPPER(TRIM(p.nombre)) = UPPER(TRIM('STARGOLD ESTANDAR'))
  AND NOT EXISTS (
    SELECT 1 FROM bal_tipo_balon t
    WHERE UPPER(TRIM(t.nombre)) = UPPER(TRIM('Stargold Estandar de 7 m3'))
  )
LIMIT 1;

COMMIT;