-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_generar_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_generar_salida(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_generar_salida(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_estado VARCHAR;
    v_tipo VARCHAR;
    v_id_generada INTEGER;
    v_det RECORD;
    v_mov JSON;
    v_id_mov INTEGER;
    v_codigo_mov VARCHAR;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo, tor.nombre AS tipo_orden
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    v_estado := v_doc.estado_ciclo;
    v_tipo := v_doc.tipo_orden;

    IF v_estado = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF v_estado IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        -- Ya produjo efectos; no se repiten.
        RETURN doc_obtener_salida(p_id);
    END IF;

    -- El tipo de movimiento depende del propósito del documento.
    v_codigo_mov := CASE v_tipo
        WHEN 'RECARGA_PLANTA_EXTERNA' THEN 'SALIDA_PLANTA_EXTERNA'
        WHEN 'RETORNO_PLANTA_EXTERNA' THEN 'ENTRADA_PLANTA_EXTERNA'
        WHEN 'TRASLADO'               THEN 'TRASLADO'
        ELSE 'SALIDA_ENTREGA_CLIENTE'
    END;

    IF v_doc.id_venta IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM doc_salida_detalle WHERE id_doc_salida = p_id AND estado = 1) THEN
            RETURN json_build_object('error', 'El documento no tiene líneas que trasladar', 'registro', NULL);
        END IF;

        FOR v_det IN
            SELECT dd.*, COALESCE(b.id_producto_gas, dd.id_producto) AS id_producto_efectivo
            FROM doc_salida_detalle dd
            LEFT JOIN bal_balon b ON b.id = dd.id_balon
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
            ORDER BY dd.item
        LOOP
            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => CASE WHEN v_det.id_balon IS NOT NULL THEN 'BALON' ELSE 'PRODUCTO' END,
                p_codigo_tipo_movimiento       => v_codigo_mov,
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => CASE WHEN v_det.id_balon IS NOT NULL
                                                       THEN v_det.id_producto_efectivo
                                                       ELSE v_det.id_producto END,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => v_det.cantidad,
                p_id_almacen_origen            => v_doc.id_almacen,
                p_id_cliente                   => COALESCE(v_doc.id_destinatario, v_doc.id_cliente, v_doc.id_proveedor),
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id,
                p_glosa                        => format('Salida por orden %s', v_doc.numero),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;

            IF COALESCE((v_mov->>'creado')::BOOLEAN, TRUE) IS NOT TRUE THEN
                RAISE EXCEPTION 'No se registró el movimiento de la línea % (duplicado)', v_det.item;
            END IF;

            v_id_mov := (v_mov->'registro'->>'id')::INTEGER;

            UPDATE doc_salida_detalle
            SET id_movimiento = v_id_mov,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id;

            v_n := v_n + 1;
        END LOOP;
    END IF;
    -- Con id_venta no se toca inventario: el movimiento lo creó la venta y este
    -- documento solo lo respalda documentalmente (apunte 1.c.iv.6).

    SELECT lo.id INTO v_id_generada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'GENERADA' AND lo.estado = 1;

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_generada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
