-- F1 cierre: granularidad documento, snapshots de custodia, gas afecta_stock, drop kardex legado.
BEGIN;

ALTER TABLE inv_movimiento
    ADD COLUMN IF NOT EXISTS id_documento_detalle integer,
    ADD COLUMN IF NOT EXISTS id_estado_balon_anterior integer,
    ADD COLUMN IF NOT EXISTS id_cliente_ubicacion_anterior integer,
    ADD COLUMN IF NOT EXISTS id_almacen_anterior integer;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'inv_movimiento_id_estado_balon_anterior_fkey'
    ) THEN
        ALTER TABLE inv_movimiento
            ADD CONSTRAINT inv_movimiento_id_estado_balon_anterior_fkey
            FOREIGN KEY (id_estado_balon_anterior) REFERENCES gen_lista_opciones(id);
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'inv_movimiento_id_almacen_anterior_fkey'
    ) THEN
        ALTER TABLE inv_movimiento
            ADD CONSTRAINT inv_movimiento_id_almacen_anterior_fkey
            FOREIGN KEY (id_almacen_anterior) REFERENCES gen_almacen(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_inv_movimiento_doc_detalle
    ON inv_movimiento (id_tipo_documento_origen, id_documento_origen, id_documento_detalle);

-- Compras antiguas: id_documento_origen era el detalle. Reasignar a cabecera.
UPDATE inv_movimiento m
SET
    id_documento_detalle = m.id_documento_origen,
    id_documento_origen = d.id_comprobante
FROM com_comprobante_compra_detalle d
WHERE d.id = m.id_documento_origen
  AND m.id_documento_detalle IS NULL
  AND EXISTS (
      SELECT 1
      FROM gen_lista_opciones tdo
      WHERE tdo.id = m.id_tipo_documento_origen
        AND tdo.nombre = 'COMPRA'
  )
  AND EXISTS (
      SELECT 1 FROM com_comprobante_compra c WHERE c.id = d.id_comprobante
  );

UPDATE pro_producto
SET afecta_stock = TRUE,
    fecha_modificacion = NOW()
WHERE es_gas = TRUE
  AND COALESCE(es_servicio, FALSE) = FALSE
  AND COALESCE(afecta_stock, FALSE) = FALSE;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
            'pro_crear_movimiento',
            'pro_actualizar_movimiento',
            'pro_listar_movimientos',
            'pro_obtener_movimiento',
            'pro_eliminar_movimiento',
            'bal_listar_movimientos',
            'bal_obtener_movimiento',
            'bal_aplicar_custodia_tipo_movimiento',
            'bal_actualizar_movimiento',
            'bal_crear_movimiento',
            'bal_eliminar_movimiento',
            'bal_movimiento_aplicar_snapshot'
          )
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig || ' CASCADE';
    END LOOP;
END $$;

COMMIT;
