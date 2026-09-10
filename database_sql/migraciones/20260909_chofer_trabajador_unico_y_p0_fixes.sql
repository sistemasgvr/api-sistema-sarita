-- ============================================================
-- Migración: UNIQUE chofer↔trabajador + fixes P0/P1
-- Fecha: 2026-09-09
--
-- 1) Un trabajador activo solo puede tener un chofer de flota propia.
-- 2) Soft-desactiva duplicados previos (conserva el id más bajo).
--
-- Las funciones actualizadas viven en database_sql/funciones/ (aplicar aparte
-- o con sync/apply según el flujo del equipo):
--   - gen_actualizar_chofer.sql
--   - gen_crear_chofer.sql
--   - bal_crear_movimiento_recarga.sql
--   - bal_actualizar_movimiento_recarga.sql
--   - dash_ganancias_del_dia.sql
--   - bal_crear_lote_protocolo.sql
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_chofer_trabajador_unico_y_p0_fixes.sql
-- ============================================================

-- Soft-delete duplicados activos: deja el chofer de menor id por trabajador.
UPDATE gen_chofer c
SET
    estado = 0,
    fecha_modificacion = NOW()
WHERE c.estado = 1
  AND c.id_trabajador IS NOT NULL
  AND c.id <> (
      SELECT MIN(c2.id)
      FROM gen_chofer c2
      WHERE c2.estado = 1
        AND c2.id_trabajador = c.id_trabajador
  );

CREATE UNIQUE INDEX IF NOT EXISTS uq_gen_chofer_id_trabajador_activo
    ON gen_chofer (id_trabajador)
    WHERE id_trabajador IS NOT NULL AND estado = 1;
