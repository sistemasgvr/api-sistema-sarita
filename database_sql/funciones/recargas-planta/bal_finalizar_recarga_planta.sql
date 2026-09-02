-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.555Z
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer DEFAULT NULL::integer, p_guardar_balones_almacen boolean DEFAULT false, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado             JSON;
    v_id_estado_en_almacen  INTEGER;
    v_id_documento_ref      INTEGER;
    v_det                   RECORD;
    v_mov                   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_recarga_planta WHERE id = p_id_recarga_planta AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La orden de recarga en planta externa no existe o está inactiva', 'registro', NULL);
    END IF;

    -- Si p_fecha_llegada_almacen viene, bal_actualizar exige lote + vencimiento + P.H. en la orden.
    v_resultado := bal_actualizar_recarga_planta(
        p_id                    => p_id_recarga_planta,
        p_id_proveedor          => p_id_proveedor,
        p_id_almacen            => p_id_almacen,
        p_id_comprobante_compra => p_id_comprobante_compra,
        p_fecha_llegada_almacen => p_fecha_llegada_almacen,
        p_id_usuario_auditoria  => p_id_usuario_auditoria
    );

    IF v_resultado->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_resultado->>'error', 'registro', NULL);
    END IF;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        -- Preferir COMPRA como documento de referencia cuando la factura ya está vinculada.
        IF p_id_comprobante_compra IS NOT NULL THEN
            v_id_documento_ref := p_id_comprobante_compra;
        ELSE
            v_id_documento_ref := p_id_recarga_planta;
        END IF;

        FOR v_det IN
            SELECT d.id_balon, COALESCE(d.id_producto, b.id_producto_gas) AS id_producto, d.capacidad
            FROM bal_recarga_planta_detalle d
            LEFT JOIN bal_balon b ON b.id = d.id_balon
            WHERE d.id_recarga_planta = p_id_recarga_planta
              AND d.estado = 1
        LOOP
            PERFORM bal_actualizar_balon(
                p_id                   => v_det.id_balon,
                p_id_almacen           => p_id_almacen,
                p_id_estado_balon      => v_id_estado_en_almacen,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );

            v_mov := inv_registrar_movimiento(
                p_naturaleza                => 'BALON',
                p_codigo_tipo_movimiento    => 'ENTRADA_LLENADO',
                p_fecha                     => NOW(),
                p_id_producto               => v_det.id_producto,
                p_id_balon                  => v_det.id_balon,
                p_cantidad                  => COALESCE(v_det.capacidad, 1),
                p_id_almacen_destino        => p_id_almacen,
                p_id_cliente                => p_id_proveedor,
                p_codigo_tipo_documento_origen => CASE
                    WHEN p_id_comprobante_compra IS NOT NULL THEN 'COMPRA'
                    ELSE 'RECARGA'
                END,
                p_id_documento_origen       => v_id_documento_ref,
                p_glosa                     => CASE
                    WHEN p_id_comprobante_compra IS NOT NULL THEN
                        'Entrada por compra #' || p_id_comprobante_compra
                        || ' (orden planta #' || p_id_recarga_planta || ')'
                    ELSE
                        'Entrada por recarga en planta externa (orden #' || p_id_recarga_planta || ')'
                END,
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el movimiento de entrada del balón %: %', v_det.id_balon, v_mov->>'error';
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id_recarga_planta', p_id_recarga_planta)
    );
END;
$function$
