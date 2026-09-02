-- =============================================================================
-- Migración: Fase B — Eliminar tablas, columnas y funciones legadas
-- Fecha: 2026-09-01
-- Descripción: Después de migrar todos los llamadores a inv_registrar_movimiento,
--              se eliminan las tablas pro_movimientos y bal_movimiento,
--              las columnas legacy de bal_balon, las funciones legadas y el trigger.
-- NO reejecutar en cadena con 20260901_inv_movimiento_fundamento.sql:
-- dropea columnas que esa migración aún referencia. Reconstrucción desde 0:
-- node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Eliminar trigger y función trigger
-- ─────────────────────────────────────────────────────────────────────────────
DROP TRIGGER IF EXISTS trg_bal_movimiento_snapshot ON bal_movimiento;
DROP FUNCTION IF EXISTS bal_movimiento_aplicar_snapshot();

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Eliminar tablas de movimiento legadas
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS bal_movimiento CASCADE;
DROP TABLE IF EXISTS pro_movimientos CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Eliminar columnas legacy de bal_balon
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE bal_balon DROP COLUMN IF EXISTS id_estado_contenido;
ALTER TABLE bal_balon DROP COLUMN IF EXISTS capacidad_restante;
ALTER TABLE bal_balon DROP COLUMN IF EXISTS capacidad_restante_lb;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Eliminar funciones legadas de movimiento
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS pro_crear_movimiento(
    DATE, INTEGER, INTEGER, INTEGER, NUMERIC, INTEGER, INTEGER, VARCHAR, INTEGER, BOOLEAN, INTEGER
);
DROP FUNCTION IF EXISTS pro_obtener_movimiento(INTEGER);
DROP FUNCTION IF EXISTS pro_listar_movimientos(INTEGER, INTEGER, DATE, DATE, INTEGER, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS pro_eliminar_movimiento(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS pro_actualizar_movimiento(INTEGER, DATE, INTEGER, INTEGER, INTEGER, NUMERIC, INTEGER, INTEGER, VARCHAR, INTEGER);

DROP FUNCTION IF EXISTS bal_crear_movimiento(
    INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TIMESTAMP, VARCHAR, INTEGER
);
DROP FUNCTION IF EXISTS bal_obtener_movimiento(INTEGER);
DROP FUNCTION IF EXISTS bal_listar_movimientos(INTEGER, INTEGER, INTEGER, DATE, DATE, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS bal_eliminar_movimiento(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS bal_actualizar_movimiento(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TIMESTAMP, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS bal_aplicar_custodia_tipo_movimiento(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TIMESTAMP, VARCHAR, INTEGER);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Eliminar funciones de capacidad/contenido legadas
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS bal_sync_capacidad_restante(
    INTEGER, NUMERIC, NUMERIC, NUMERIC, VARCHAR, NUMERIC, INTEGER
);
DROP FUNCTION IF EXISTS bal_id_estado_contenido(VARCHAR);
DROP FUNCTION IF EXISTS bal_capacidad_disponible_balon(INTEGER);
DROP FUNCTION IF EXISTS bal_consumir_capacidad_balon_origen(INTEGER, NUMERIC, INTEGER);
DROP FUNCTION IF EXISTS bal_consumir_capacidad_origenes_recarga(INTEGER, NUMERIC, INTEGER);
DROP FUNCTION IF EXISTS bal_factor_lb_m3();

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. EliminarFKs que referencian tablas/enum eliminados (si existen)
-- ─────────────────────────────────────────────────────────────────────────────
-- Nota: Las FKs se eliminan automáticamente con CASCADE al dropear las tablas.

COMMIT;
