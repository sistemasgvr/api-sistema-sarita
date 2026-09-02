-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_eliminar_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.635Z
DROP FUNCTION IF EXISTS com_eliminar_compra_detalle(p_id_detalle integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_eliminar_compra_detalle(p_id_detalle integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_result_movimiento   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        d.id,
        d.id_comprobante,
        d.id_producto,
        d.cantidad,
        d.afecta_stock,
        COALESCE(d.id_almacen, c.id_almacen) AS id_almacen,
        c.serie,
        c.numero
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    WHERE d.id = p_id_detalle AND d.estado = 1 AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_detalle);
    END IF;

    v_serie := v_detalle.serie;
    v_numero := v_detalle.numero;

    IF v_detalle.afecta_stock THEN
        v_result_movimiento := inv_registrar_movimiento(
            p_naturaleza                => 'PRODUCTO',
            p_codigo_tipo_movimiento    => 'SALIDA',
            p_fecha                     => CURRENT_DATE,
            p_id_producto               => v_detalle.id_producto,
            p_cantidad                  => v_detalle.cantidad,
            p_id_almacen_origen         => v_detalle.id_almacen,
            p_codigo_tipo_documento_origen => 'DEVOLUCION',
            p_id_documento_origen       => v_detalle.id,
            p_glosa                     => 'Reversa por eliminación de línea compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria      => p_id_usuario_auditoria,
            p_forzar                    => TRUE
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id_detalle,
                'error', v_result_movimiento->>'error'
            );
        END IF;
    END IF;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    UPDATE com_comprobante_compra
    SET afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_detalle.id_comprobante
              AND afecta_stock = TRUE
              AND estado = 1
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_detalle.id_comprobante;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_detalle);
END;
$function$
