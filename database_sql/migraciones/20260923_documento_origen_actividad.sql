-- ============================================================
-- Migracion: 'ACTIVIDAD' en el catalogo TipoDocumentoRef
-- Fecha: 2026-09-23
--
-- Contexto: al culminar un recojo, si un cilindro vuelve con contenido (gas
-- remanente), ese ajuste de stock se registra con el flujo normal de
-- movimientos de inventario (naturaleza PRODUCTO, tipo REPOSICION) desde la
-- pantalla de la actividad -- no se crea un flujo aparte. Lo unico que hacia
-- falta era poder referenciar ese movimiento a la actividad puntual via
-- codigo_tipo_documento_origen/id_documento_origen (inv_registrar_movimiento
-- ya soporta ambos parametros end-to-end, front y back).
--
-- El frontend (admin-sistema-sarita/src/modules/inventario/utils/
-- documentoOrigenRoute.ts) ya tenia el caso 'ACTIVIDAD' resuelto para poder
-- enlazar de vuelta a la actividad desde un movimiento -- solo faltaba esta
-- opcion en el catalogo TipoDocumentoRef, sin la cual inv_registrar_movimiento
-- rechaza el movimiento con "Tipo de documento origen ACTIVIDAD no
-- configurado".
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260923_documento_origen_actividad.sql
-- ============================================================

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, estado)
SELECT l.id, 'ACTIVIDAD', 'Actividad (reparto / recojo)', 1
FROM gen_lista l
WHERE l.nombre = 'TipoDocumentoRef'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND UPPER(TRIM(lo.nombre)) = 'ACTIVIDAD'
  );
