-- Registra la salida de los cilindros incluidos en una guía de remisión
DROP FUNCTION IF EXISTS public.bal_aplicar_salidas_guia_remision (p_id_guia integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.bal_aplicar_salidas_guia_remision (
  p_id_guia integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_almacen INTEGER;
    v_id_cliente INTEGER;
    v_id_destinatario INTEGER;
    v_id_motivo INTEGER;
    v_observaciones VARCHAR;
    v_motivo_codigo VARCHAR;
    v_motivo_nombre VARCHAR;
    v_es_planta BOOLEAN := FALSE;
    v_id_cliente_ubicacion INTEGER;
    v_codigo_tipo_mov VARCHAR;
    v_codigo_estado VARCHAR;
    v_id_balon INTEGER;
    v_balones INTEGER[] := ARRAY[]::INTEGER[];
    v_result JSON;
    v_serie VARCHAR;
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        g.id_almacen,
        g.id_cliente,
        g.id_destinatario,
        g.id_motivo_traslado,
        g.observaciones,
        g.serie,
        g.numero_sunat
    INTO
        v_id_almacen,
        v_id_cliente,
        v_id_destinatario,
        v_id_motivo,
        v_observaciones,
        v_serie,
        v_numero
    FROM doc_salida g
    WHERE g.id = p_id_guia AND g.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Guía de remisión no encontrada', 'ok', FALSE);
    END IF;

    SELECT lo.descripcion, lo.nombre
    INTO v_motivo_codigo, v_motivo_nombre
    FROM gen_lista_opciones lo
    WHERE lo.id = v_id_motivo AND lo.estado = 1;

    v_es_planta := COALESCE(v_motivo_codigo, '') = '13'
        OR (
            UPPER(COALESCE(v_motivo_nombre, '')) = 'OTROS'
            AND (
                COALESCE(v_observaciones, '') ILIKE '%planta%'
                OR COALESCE(v_observaciones, '') ILIKE '%recarga%'
            )
        );

    IF v_es_planta THEN
        v_codigo_tipo_mov := 'SALIDA_PLANTA_EXTERNA';
        v_codigo_estado := 'EN_RECARGA_EXTERNA';
        v_id_cliente_ubicacion := NULL;
    ELSIF v_id_cliente IS NOT NULL OR v_id_destinatario IS NOT NULL THEN
        v_codigo_tipo_mov := 'SALIDA_PRESTAMO';
        v_codigo_estado := 'PRESTADO_CLIENTE';
        v_id_cliente_ubicacion := COALESCE(v_id_cliente, v_id_destinatario);
    ELSE
        v_codigo_tipo_mov := 'TRASLADO_LIMA';
        v_codigo_estado := 'EN_RUTA_LIMA';
        v_id_cliente_ubicacion := NULL;
    END IF;

    FOR v_id_balon IN
        SELECT d.id_balon
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_guia
          AND d.estado = 1
          AND d.id_balon IS NOT NULL
        ORDER BY d.item, d.id
    LOOP
        IF v_id_balon = ANY (v_balones) THEN
            RETURN json_build_object(
                'error',
                format('El cilindro %s está duplicado en la guía', v_id_balon),
                'ok',
                FALSE
            );
        END IF;
        v_balones := array_append(v_balones, v_id_balon);

        v_result := bal_registrar_salida_documento(
            v_id_balon,
            v_codigo_tipo_mov,
            p_id_guia,
            'GRE',
            v_id_cliente_ubicacion,
            v_id_almacen,
            v_codigo_estado,
            TRUE,
            NULL,
            format(
                'Salida automática GRE %s-%s',
                COALESCE(v_serie, ''),
                COALESCE(v_numero, '')
            ),
            p_id_usuario_auditoria
        );

        IF v_result->>'error' IS NOT NULL THEN
            RETURN json_build_object(
                'error',
                format('Cilindro %s: %s', v_id_balon, v_result->>'error'),
                'ok',
                FALSE
            );
        END IF;
    END LOOP;

    RETURN json_build_object(
        'ok', TRUE,
        'cantidad', COALESCE(array_length(v_balones, 1), 0),
        'error', NULL
    );
END;
$function$;
