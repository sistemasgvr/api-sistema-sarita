-- Anula un documento de salida y libera la custodia de sus cilindros
DROP FUNCTION IF EXISTS public.doc_anular_salida (
  p_id integer,
  p_motivo character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.doc_anular_salida (
  p_id integer,
  p_motivo character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_doc RECORD;
    v_compra RECORD;
    v_id_anulada INTEGER;
    v_rev JSON;
    v_id_disponible INTEGER;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
    v_balon RECORD;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o ya fue eliminado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN doc_obtener_salida(p_id);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object(
            'error',
            'El documento fue aceptado por SUNAT; requiere comunicación de baja, no anulación directa',
            'registro', NULL
        );
    END IF;

    IF NULLIF(TRIM(COALESCE(v_doc.ticket_sunat, '')), '') IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'La guía tiene un ticket SUNAT pendiente; consulta el CDR o espera la aceptación antes de anular',
            'registro', NULL
        );
    END IF;

    IF v_doc.id_comprobante_compra IS NOT NULL AND EXISTS (
        SELECT 1 FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra AND c.estado = 1
    ) THEN
        SELECT c.serie, c.numero INTO v_compra
        FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra;

        RETURN json_build_object(
            'error', format(
                'La orden tiene la compra %s vinculada; anúlala primero en Compras',
                COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), ''), '#' || v_doc.id_comprobante_compra)
            ),
            'registro', NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'error',
            'El reparto de esta orden ya fue entregado al cliente; no se puede anular. '
            || 'Registra la devolución de los cilindros o emite una nota de crédito.',
            'registro', NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN (
              'CANCELADA', 'CANCELADO', 'REALIZADA'
          )
    ) THEN
        RETURN json_build_object(
            'error', 'Hay actividad de reparto vigente; cancélala antes de anular la OS',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_disponible
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_disponible IS NULL OR v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados DISPONIBLE, PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_anulada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'ANULADA' AND lo.estado = 1;

    IF v_id_anulada IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado ANULADA en catalogo EstadoCicloSalida',
            'registro', NULL
        );
    END IF;

    IF v_doc.id_venta IS NULL THEN
        v_rev := inv_revertir_por_documento('ORDEN_SALIDA', p_id, p_id_usuario_auditoria);

        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;

        UPDATE doc_salida_detalle
        SET id_movimiento = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_doc_salida = p_id;
    END IF;

    -- Los cilindros de la orden que siguen pendientes de envío / en tránsito
    -- vuelven al almacén. Si su último movimiento vigente es una salida (p. ej.
    -- "Salida préstamo" registrada con la venta), el retorno se registra como
    -- ENTRADA_DEVOLUCION para que el historial del cilindro lo muestre; antes
    -- se cambiaba el estado con un UPDATE directo y el historial quedaba en la
    -- salida, con el cliente aún como ubicación.
    FOR v_balon IN
        SELECT b.id,
               COALESCE(v_doc.id_almacen, b.id_almacen) AS id_almacen_destino,
               ult.id_cliente,
               COALESCE(inv_signo_tipo_movimiento(ult.id_tipo_movimiento), 0) < 0 AS ultimo_es_salida
        FROM bal_balon b
        LEFT JOIN LATERAL (
            SELECT m.id_tipo_movimiento, m.id_cliente
            FROM inv_movimiento m
            WHERE m.estado = 1 AND m.naturaleza = 'BALON' AND m.id_balon = b.id
            ORDER BY m.fecha DESC, m.id DESC
            LIMIT 1
        ) ult ON TRUE
        WHERE b.estado = 1
          AND b.id_estado_balon IN (v_id_pend_envio, v_id_transito)
          AND b.id IN (
              SELECT dd.id_balon
              FROM doc_salida_detalle dd
              WHERE dd.id_doc_salida = p_id
                AND dd.id_balon IS NOT NULL
                AND dd.estado = 1
              UNION
              SELECT vd.id_balon
              FROM ven_comprobante_detalle vd
              WHERE v_doc.id_venta IS NOT NULL
                AND vd.id_comprobante = v_doc.id_venta
                AND vd.id_balon IS NOT NULL
                AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
              UNION
              SELECT pd.id_balon
              FROM bal_prestamo pr
              INNER JOIN bal_prestamo_detalle pd
                  ON pd.id_prestamo = pr.id AND pd.estado = 1
              WHERE v_doc.id_venta IS NOT NULL
                AND pr.id_comprobante_venta = v_doc.id_venta
                AND pr.estado = 1
                AND pd.rol = 'ENTREGADO'
                AND pd.id_balon IS NOT NULL
          )
    LOOP
        IF v_balon.ultimo_es_salida AND v_balon.id_almacen_destino IS NOT NULL THEN
            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'BALON',
                p_codigo_tipo_movimiento       => 'ENTRADA_DEVOLUCION',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_balon                     => v_balon.id,
                p_cantidad                     => 1,
                p_id_almacen_destino           => v_balon.id_almacen_destino,
                p_id_cliente                   => v_balon.id_cliente,
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id,
                p_glosa                        => LEFT(format(
                    'Retorno a almacén por anulación de orden %s: %s',
                    COALESCE(v_doc.numero, '#' || p_id),
                    COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado')
                ), 300),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_forzar                       => TRUE
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;
        ELSE
            UPDATE bal_balon
            SET id_estado_balon = v_id_disponible,
                id_almacen = v_balon.id_almacen_destino,
                id_cliente_ubicacion = NULL,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_balon.id;
        END IF;
    END LOOP;


    UPDATE doc_salida
    SET id_estado_ciclo = v_id_anulada,
        observaciones = TRIM(BOTH ' ' FROM CONCAT_WS(' | ',
            NULLIF(observaciones, ''),
            'Anulada: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'))),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
