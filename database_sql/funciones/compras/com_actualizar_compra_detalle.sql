-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_actualizar_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
DROP FUNCTION IF EXISTS com_actualizar_compra_detalle(p_id_detalle integer, p_cantidad numeric, p_precio_unitario numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_actualizar_compra_detalle(p_id_detalle integer, p_cantidad numeric DEFAULT NULL::numeric, p_precio_unitario numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_nueva_cantidad      NUMERIC(12,4);
    v_nuevo_precio        NUMERIC(12,6);
    v_delta               NUMERIC(12,4);
    v_importe             NUMERIC(12,4);
    v_result_movimiento   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        d.id,
        d.id_comprobante,
        d.id_producto,
        d.cantidad,
        d.precio_unitario,
        d.afecta_stock,
        COALESCE(d.id_almacen, c.id_almacen) AS id_almacen,
        c.fecha,
        c.serie,
        c.numero
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    WHERE d.id = p_id_detalle
      AND d.estado = 1
      AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('error', 'La línea no existe o la compra está anulada', 'registro', NULL);
    END IF;

    v_nueva_cantidad := COALESCE(p_cantidad, v_detalle.cantidad);
    v_nuevo_precio := COALESCE(p_precio_unitario, v_detalle.precio_unitario);

    IF v_nueva_cantidad IS NULL OR v_nueva_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_nuevo_precio IS NULL OR v_nuevo_precio < 0 THEN
        RETURN json_build_object('error', 'El precio unitario no puede ser negativo', 'registro', NULL);
    END IF;

    -- Sin cambios relevantes
    IF v_nueva_cantidad = v_detalle.cantidad
       AND COALESCE(v_nuevo_precio, 0) = COALESCE(v_detalle.precio_unitario, 0)
    THEN
        RETURN com_obtener_compra(v_detalle.id_comprobante);
    END IF;

    v_delta := v_nueva_cantidad - v_detalle.cantidad;

    IF v_detalle.afecta_stock AND v_delta <> 0 THEN
        v_result_movimiento := inv_revertir_por_documento(
            'COMPRA',
            v_detalle.id_comprobante,
            p_id_usuario_auditoria,
            v_detalle.id
        );
        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RETURN json_build_object('error', v_result_movimiento->>'error', 'registro', NULL);
        END IF;

        v_result_movimiento := inv_registrar_movimiento(
            p_naturaleza                => 'PRODUCTO',
            p_codigo_tipo_movimiento    => 'INGRESO',
            p_fecha                     => v_detalle.fecha,
            p_id_producto               => v_detalle.id_producto,
            p_cantidad                  => v_nueva_cantidad,
            p_id_almacen_origen         => v_detalle.id_almacen,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen       => v_detalle.id_comprobante,
            p_id_documento_detalle      => v_detalle.id,
            p_glosa                     => 'Ingreso por compra ' || v_detalle.serie || '-' || v_detalle.numero,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RETURN json_build_object('error', v_result_movimiento->>'error', 'registro', NULL);
        END IF;
    END IF;

    v_importe := v_nueva_cantidad * v_nuevo_precio;

    UPDATE com_comprobante_compra_detalle
    SET cantidad = v_nueva_cantidad,
        precio_unitario = v_nuevo_precio,
        importe = v_importe,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN com_obtener_compra(v_detalle.id_comprobante);
END;
$function$;
