-- ============================================================
-- Migración: Fase 8 (apunte 7.a.i) — el tipo de documento pasa de VSD a SD
-- Fecha: 2026-09-08
--
-- "Sin documento" como TIPO DE DOCUMENTO DEL CLIENTE se etiqueta SD.
--
-- Ojo con el homónimo: en la lista TipoComprobante, VSD significa "venta sin
-- documento" y NO se toca. Esta migración solo renombra la opción de la lista
-- TipoDocumento; el resto del sistema sigue usando VSD para el comprobante.
--
-- Al momento de escribirla ningún cliente usa este tipo, así que el rename no
-- arrastra datos. La condición de abajo lo verifica igual.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260908_f8_tipo_documento_sd.sql
-- ============================================================

UPDATE gen_lista_opciones lo
SET nombre = 'SD',
    descripcion = 'Cliente sin documento',
    fecha_modificacion = NOW()
FROM gen_lista l
WHERE l.id = lo.id_lista
  AND l.nombre = 'TipoDocumento'
  AND lo.nombre = 'VSD'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones dup
      WHERE dup.id_lista = lo.id_lista AND dup.nombre = 'SD'
  );
