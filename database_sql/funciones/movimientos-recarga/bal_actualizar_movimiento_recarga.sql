-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
DROP FUNCTION IF EXISTS bal_actualizar_movimiento_recarga(p_id integer, p_fecha_salida_almacen date, p_id_producto integer, p_capacidad numeric, p_id_unidad_medida integer, p_serie_guia_salida character varying, p_numero_guia_salida character varying, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_serie_factura character varying, p_numero_factura character varying, p_id_comprobante integer, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_proveedor integer, p_observacion character varying, p_id_almacen integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_movimiento_recarga(p_id integer, p_fecha_salida_almacen date DEFAULT NULL::date, p_id_producto integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_serie_guia_salida character varying DEFAULT NULL::character varying, p_numero_guia_salida character varying DEFAULT NULL::character varying, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_serie_factura character varying DEFAULT NULL::character varying, p_numero_factura character varying DEFAULT NULL::character varying, p_id_comprobante integer DEFAULT NULL::integer, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_proveedor integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_fecha_llegada_antes DATE;
    v_fecha_llegada DATE;
    v_id_producto INTEGER;
    v_id_almacen INTEGER;
    v_id_proveedor INTEGER;
    v_capacidad_tipo NUMERIC;
    v_id_estado_en_almacen INTEGER;
    v_id_documento_ref INTEGER;
    v_id_compra INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_ya_tiene_entrada BOOLEAN;
    v_capacidad NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'El comprobante de compra indicado no existe o está inactivo',
            'registro',
            NULL
        );
    END IF;

    SELECT fecha_llegada_almacen
    INTO v_fecha_llegada_antes
    FROM bal_movimiento_recarga
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE bal_movimiento_recarga
    SET
        fecha_salida_almacen = COALESCE(p_fecha_salida_almacen, fecha_salida_almacen),
        id_producto = COALESCE(p_id_producto, id_producto),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        serie_guia_salida = COALESCE(p_serie_guia_salida, serie_guia_salida),
        numero_guia_salida = COALESCE(p_numero_guia_salida, numero_guia_salida),
        serie_guia_ingreso = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
        numero_guia_ingreso = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
        serie_factura = COALESCE(p_serie_factura, serie_factura),
        numero_factura = COALESCE(p_numero_factura, numero_factura),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = CASE
            WHEN p_lote IS NOT NULL THEN NULLIF(TRIM(p_lote), '')
            ELSE lote
        END,
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        observacion = COALESCE(p_observacion, observacion),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1
    RETURNING id_balon, fecha_llegada_almacen, id_producto, id_almacen, id_proveedor, observacion, capacidad
    INTO v_id_balon, v_fecha_llegada, v_id_producto, v_id_almacen, v_id_proveedor, v_obs, v_capacidad;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_fecha_llegada IS NOT NULL AND v_id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el estado EN_ALMACEN del cilindro. Revise el catálogo EstadoBalon.',
                'registro',
                NULL
            );
        END IF;

        SELECT COALESCE(tb.capacidad, p_capacidad, 0)
        INTO v_capacidad_tipo
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        WHERE b.id = v_id_balon;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_en_almacen,
            id_almacen = COALESCE(v_id_almacen, id_almacen),
            id_producto_gas = COALESCE(v_id_producto, id_producto_gas),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon AND estado = 1;

        -- Primera vez que se registra llegada: movimiento de entrada.
        -- Si ya hay compra vinculada, el documento de referencia es COMPRA (no GRE/RECARGA).
        IF v_fecha_llegada_antes IS NULL THEN
            SELECT COALESCE(p_id_comprobante_compra, id_comprobante_compra)
            INTO v_id_compra
            FROM bal_movimiento_recarga
            WHERE id = p_id;

            IF v_id_compra IS NOT NULL THEN
                v_id_documento_ref := v_id_compra;
            ELSE
                v_id_documento_ref := p_id;
            END IF;

            SELECT EXISTS (
                SELECT 1
                FROM inv_movimiento m
                INNER JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND m.id_balon = v_id_balon
                  AND tm.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND (
                    m.id_documento_origen = p_id
                    OR (v_id_compra IS NOT NULL AND m.id_documento_origen = v_id_compra)
                  )
            ) INTO v_ya_tiene_entrada;

            IF NOT COALESCE(v_ya_tiene_entrada, FALSE) THEN
                v_mov := inv_registrar_movimiento(
                    p_naturaleza                => 'BALON',
                    p_codigo_tipo_movimiento    => 'ENTRADA_PLANTA_EXTERNA',
                    p_fecha                     => v_fecha_llegada,
                    p_id_producto               => v_id_producto,
                    p_id_balon                  => v_id_balon,
                    p_cantidad                  => COALESCE(v_capacidad, 1),
                    p_id_almacen_destino        => v_id_almacen,
                    p_id_cliente                => v_id_proveedor,
                    p_codigo_tipo_documento_origen => CASE
                        WHEN v_id_compra IS NOT NULL THEN 'COMPRA'
                        ELSE 'RECARGA'
                    END,
                    p_id_documento_origen       => v_id_documento_ref,
                    p_glosa                     => COALESCE(
                        NULLIF(TRIM(v_obs), ''),
                        CASE
                            WHEN v_id_compra IS NOT NULL THEN 'Retorno planta externa (compra #' || v_id_compra || ')'
                            ELSE 'Retorno planta externa'
                        END
                    ),
                    p_id_usuario_auditoria      => p_id_usuario_auditoria
                );
                IF v_mov->>'error' IS NOT NULL THEN
                    RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
                END IF;
            END IF;
        ELSIF p_id_comprobante_compra IS NOT NULL THEN
            -- Compra vinculada después de la entrada: reapunta el kardex a COMPRA.
            v_mov := inv_repuntar_documento(
                p_codigo_tipo_documento_origen_actual => 'RECARGA',
                p_id_documento_origen_actual          => p_id,
                p_codigo_tipo_documento_origen_nuevo  => 'COMPRA',
                p_id_documento_origen_nuevo           => p_id_comprobante_compra,
                p_id_usuario_auditoria                => p_id_usuario_auditoria
            );
        END IF;
    END IF;

    -- Idempotente: solo inserta en bal_balon_ph_historial si hay P.H. y aún no hay fila para este movimiento.
    PERFORM bal_sync_ph_desde_recarga(p_id, p_id_usuario_auditoria);

    RETURN bal_obtener_movimiento_recarga(p_id);
END;
$function$;
