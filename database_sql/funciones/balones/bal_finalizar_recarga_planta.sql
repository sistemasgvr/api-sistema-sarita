-- Registra el retorno de una recarga en planta externa: balones, gas y ficha
DROP FUNCTION IF EXISTS public.bal_finalizar_recarga_planta (
  p_id_recarga_planta integer,
  p_id_comprobante_compra integer,
  p_fecha_llegada_almacen date,
  p_id_almacen integer,
  p_id_proveedor integer,
  p_guardar_balones_almacen boolean,
  p_lote character varying,
  p_fecha_vencimiento_lote date,
  p_fecha_prueba_hidrostatica date,
  p_id_usuario_auditoria integer,
  p_id_lote_protocolo integer
);

CREATE OR REPLACE FUNCTION public.bal_finalizar_recarga_planta (
  p_id_recarga_planta integer,
  p_id_comprobante_compra integer,
  p_fecha_llegada_almacen date,
  p_id_almacen integer,
  p_id_proveedor integer DEFAULT NULL::integer,
  p_guardar_balones_almacen boolean DEFAULT FALSE,
  p_lote character varying DEFAULT NULL::character varying,
  p_fecha_vencimiento_lote date DEFAULT NULL::date,
  p_fecha_prueba_hidrostatica date DEFAULT NULL::date,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_id_lote_protocolo integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_orden RECORD;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_entrada_planta INTEGER;
    v_retorno_fisico BOOLEAN;
    v_retorno_por_recojo BOOLEAN;
    v_det RECORD;
    v_mov JSON;
    v_gas JSON;
    v_id_balones INTEGER[];
    v_id_lote_aplicar INTEGER;
    v_aplic JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id, d.id_comprobante_compra, ec.nombre AS estado_ciclo, tor.nombre AS tipo_orden
    INTO v_orden
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    WHERE d.id = p_id_recarga_planta AND d.estado = 1
    FOR UPDATE OF d;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
        RETURN json_build_object(
            'error', 'El documento no es una orden de recarga en planta externa',
            'registro', NULL
        );
    END IF;

    IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        RETURN json_build_object(
            'error', CASE
                WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden está anulada'
                ELSE 'La orden aún está en borrador: genérala antes de registrar el retorno'
            END,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_entrada_planta
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_entrada_planta IS NULL THEN
        RETURN json_build_object(
            'error', 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado',
            'registro', NULL
        );
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM inv_movimiento m
        JOIN doc_salida_detalle d ON d.id = m.id_documento_detalle
        WHERE m.estado = 1
          AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
          AND m.naturaleza = 'BALON'
          AND d.id_doc_salida = p_id_recarga_planta
          AND d.id_balon IS NOT NULL
          AND m.id_balon = d.id_balon
    ) INTO v_retorno_fisico;

    IF p_guardar_balones_almacen THEN
        IF v_retorno_fisico THEN
            RETURN json_build_object(
                'error', 'El retorno de esta orden ya fue registrado; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
            JOIN gen_lista_opciones td ON td.id = m.id_tipo_documento_origen
            JOIN doc_salida_detalle d
                ON d.id_doc_salida = p_id_recarga_planta
               AND d.estado = 1
               AND d.id_balon = m.id_balon
            WHERE m.estado = 1
              AND m.naturaleza = 'BALON'
              AND UPPER(TRIM(tm.nombre)) = 'ENTRADA_LLENADO'
              AND UPPER(TRIM(td.nombre)) = 'RECARGA'
              AND m.id_documento_origen = p_id_recarga_planta
        ) INTO v_retorno_por_recojo;

        IF v_retorno_por_recojo THEN
            RETURN json_build_object(
                'error', 'Los cilindros de esta orden ya volvieron por el recojo; no se vuelve a mover inventario',
                'registro', NULL
            );
        END IF;

        IF p_id_almacen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'Indica el almacén al que llegan los cilindros',
                'registro', NULL
            );
        END IF;
    END IF;

    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = CASE
            WHEN p_guardar_balones_almacen OR v_retorno_fisico
                THEN COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen)
            ELSE fecha_llegada_almacen
        END,
        fecha_retorno = CASE
            WHEN p_guardar_balones_almacen OR v_retorno_fisico
                THEN COALESCE(p_fecha_llegada_almacen, fecha_retorno)
            ELSE fecha_retorno
        END,
        id_almacen_retorno = CASE
            WHEN p_guardar_balones_almacen THEN COALESCE(p_id_almacen, id_almacen_retorno)
            ELSE id_almacen_retorno
        END,
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_lote_protocolo = COALESCE(p_id_lote_protocolo, id_lote_protocolo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_recarga_planta;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        FOR v_det IN
            SELECT
                d.id AS id_detalle,
                d.id_balon
            FROM doc_salida_detalle d
            WHERE d.id_doc_salida = p_id_recarga_planta
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
            ORDER BY d.item
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
                p_id_producto                  => NULL,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => 1,
                p_id_almacen_destino           => p_id_almacen,
                p_id_cliente                   => p_id_proveedor,
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id_recarga_planta,
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

        v_retorno_fisico := TRUE;

        v_gas := bal_sincronizar_gas_retorno_planta(p_id_recarga_planta, p_id_usuario_auditoria);
    END IF;

    v_id_lote_aplicar := COALESCE(
        p_id_lote_protocolo,
        (SELECT d.id_lote_protocolo FROM doc_salida d WHERE d.id = p_id_recarga_planta)
    );

    IF v_id_lote_aplicar IS NOT NULL THEN
        SELECT array_agg(d.id_balon ORDER BY d.item)
        INTO v_id_balones
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_recarga_planta
          AND d.estado = 1
          AND d.id_balon IS NOT NULL;

        IF array_length(v_id_balones, 1) IS NOT NULL THEN
            v_aplic := bal_aplicar_lote_protocolo_balones(
                v_id_lote_aplicar,
                array_to_json(v_id_balones),
                p_id_usuario_auditoria,
                p_id_recarga_planta
            );
            IF v_aplic->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_aplic->>'error';
            END IF;
        ELSIF p_id_lote_protocolo IS NOT NULL THEN
            UPDATE doc_salida
            SET id_lote_protocolo = p_id_lote_protocolo
            WHERE id = p_id_recarga_planta AND estado = 1
              AND id_lote_protocolo IS DISTINCT FROM p_id_lote_protocolo;
        END IF;
    END IF;

    IF v_retorno_fisico THEN
        PERFORM bal_sync_ph_desde_orden_salida(p_id_recarga_planta, p_id_usuario_auditoria);
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta,
        'retorno_fisico', v_retorno_fisico,
        'gas', v_gas->'registro'
    ));
END;
$function$;
