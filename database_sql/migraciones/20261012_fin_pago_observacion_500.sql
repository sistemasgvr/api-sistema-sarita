-- ============================================================
-- Migracion: fin_pago.observacion a varchar(500)
-- Fecha: 2026-10-12
--
-- Síntoma: registrar un pago con una observación de más de 255
-- caracteres devolvía 500 con `value too long for type character
-- varying(255)` (SQLSTATE 22001) desde fin_registrar_pago.
--
-- Causa: fin_pago era la única tabla del esquema con `observacion`
-- en varchar(255). Las otras ~25 (fin_cuenta, fin_garantia,
-- fin_caja_gasto, fin_caja_deposito, ven_garantia, ...) usan
-- varchar(500). El DTO tampoco traía @MaxLength, así que el texto
-- pasaba el ValidationPipe y reventaba en el INSERT.
--
-- Ampliar a 500 alinea pagos con el resto del sistema y deja sitio
-- para detalle real en las observaciones. El accompanying DTO
-- (registrar-pago.dto.ts) queda en @MaxLength(500) para que el
-- frontend reciba un 400 con mensaje en vez de un 500 opaco.
--
-- El ALTER no reescribe filas (varchar→varchar sin cambio de tipo
-- base) pero sí toma ACCESS EXCLUSIVE; en tablas chicas es
-- inmediato. Si fin_pago creciera mucho, usar:
--   ADD COLUMN observacion_nuevo varchar(500) / UPDATE / DROP / RENAME
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20261012_fin_pago_observacion_500.sql
-- ============================================================

BEGIN;

ALTER TABLE fin_pago
    ALTER COLUMN observacion TYPE character varying(500);

COMMIT;
