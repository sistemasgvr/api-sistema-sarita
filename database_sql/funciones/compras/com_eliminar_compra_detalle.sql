-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_eliminar_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · un error al revertir el INGRESO se levanta con RAISE (misma regla que el
--     resto de mutaciones de inventario: todo o nada);
--   · si la línea era de gas de una compra vinculada a una orden de planta con
--     retorno registrado, el gas ingresado se re-sincroniza sin esa línea.
DROP FUNCTION IF EXISTS com_eliminar_compra_detalle(p_id_detalle integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_eliminar_compra_detalle(p_id_detalle integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
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
        c.numero,
        c.id_doc_salida,
        COALESCE(p.es_gas, FALSE) AS es_gas
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    LEFT JOIN pro_producto p ON p.id = d.id_producto
    WHERE d.id = p_id_detalle AND d.estado = 1 AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_detalle);
    END IF;

    IF v_detalle.afecta_stock THEN
        v_result_movimiento := inv_revertir_por_documento(
            'COMPRA',
            v_detalle.id_comprobante,
            p_id_usuario_auditoria,
            v_detalle.id
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;
    END IF;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    -- Gas de una compra de planta: sin esta línea lo facturado cambia y el
    -- stock del retorno debe reflejarlo (o volver a lo declarado en la orden
    -- si era la última línea de gas).
    IF v_detalle.id_doc_salida IS NOT NULL AND v_detalle.es_gas THEN
        PERFORM bal_sincronizar_gas_retorno_planta(v_detalle.id_doc_salida, p_id_usuario_auditoria);
    END IF;

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
$function$;
