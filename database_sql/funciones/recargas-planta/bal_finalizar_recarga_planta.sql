-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_id_usuario_auditoria integer);

-- p_lote / p_fecha_vencimiento_lote / p_fecha_prueba_hidrostatica: antes los
-- llenaba bal_actualizar_recarga_planta (eliminada en la unificación a
-- doc_salida). Es el mismo paso del flujo — registrar el retorno — así que
-- se agregan aquí en vez de crear otra función.
CREATE OR REPLACE FUNCTION bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer DEFAULT NULL::integer, p_guardar_balones_almacen boolean DEFAULT false, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_en_almacen INTEGER;
    v_id_documento_ref INTEGER;
    v_codigo_doc VARCHAR;
    v_det RECORD;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM doc_salida WHERE id = p_id_recarga_planta AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    -- Datos del retorno sobre el propio documento.
    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        fecha_retorno = COALESCE(p_fecha_llegada_almacen, fecha_retorno),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_recarga_planta;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        -- Con factura vinculada el documento de referencia es la compra; si no, la orden.
        IF p_id_comprobante_compra IS NOT NULL THEN
            v_id_documento_ref := p_id_comprobante_compra;
            v_codigo_doc := 'COMPRA';
        ELSE
            v_id_documento_ref := p_id_recarga_planta;
            v_codigo_doc := 'ORDEN_SALIDA';
        END IF;

        FOR v_det IN
            SELECT
                d.id AS id_detalle,
                d.id_balon,
                COALESCE(d.id_producto, b.id_producto_gas) AS id_producto,
                inv_convertir_a_unidad_producto(
                    COALESCE(d.id_producto, b.id_producto_gas),
                    d.cantidad,
                    d.id_unidad_medida
                ) AS cantidad
            FROM doc_salida_detalle d
            LEFT JOIN bal_balon b ON b.id = d.id_balon
            WHERE d.id_doc_salida = p_id_recarga_planta
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
        LOOP
            PERFORM bal_actualizar_balon(
                p_id                   => v_det.id_balon,
                p_id_almacen           => p_id_almacen,
                p_id_estado_balon      => v_id_estado_en_almacen,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );

            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'BALON',
                p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_det.id_producto,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => COALESCE(v_det.cantidad, 1),
                p_id_almacen_destino           => p_id_almacen,
                p_id_cliente                   => p_id_proveedor,
                p_codigo_tipo_documento_origen => v_codigo_doc,
                p_id_documento_origen          => v_id_documento_ref,
                p_glosa                        => format(
                    'Entrada por recarga en planta externa (orden #%s)', p_id_recarga_planta
                ),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id_detalle
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar la entrada del balón %: %',
                    v_det.id_balon, v_mov->>'error';
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta
    ));
END;
$function$;
