-- Pasa a poder del cliente los cilindros reservados de una venta de mostrador
DROP FUNCTION IF EXISTS public.ven_confirmar_entrega_mostrador (p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.ven_confirmar_entrega_mostrador (
  p_id_comprobante integer,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_pend_envio INTEGER;
    v_id_en_poder INTEGER;
    v_actualizados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT c.id_cliente INTO v_id_cliente
    FROM ven_comprobante c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La venta no existe o está anulada', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id_comprobante
          AND d.estado = 1
          AND UPPER(TRIM(ec.nombre)) <> 'ANULADA'
    ) THEN
        RETURN json_build_object(
            'error',
            'La venta tiene una orden de salida vigente: la entrega se cierra al culminar el reparto',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_en_poder
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_PODER_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_pend_envio IS NULL OR v_id_en_poder IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan los estados PENDIENTE_ENVIO o EN_PODER_CLIENTE en el catálogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    UPDATE bal_balon b
    SET id_estado_balon = v_id_en_poder,
        id_cliente_ubicacion = COALESCE(b.id_cliente_ubicacion, v_id_cliente),
        id_almacen = NULL,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    FROM ven_comprobante_detalle d
    WHERE d.id_comprobante = p_id_comprobante
      AND d.estado = 1
      AND d.id_balon = b.id
      AND b.estado = 1
      AND b.id_estado_balon = v_id_pend_envio
      AND COALESCE(d.descripcion, '') !~* 'garant[ií]a';

    GET DIAGNOSTICS v_actualizados = ROW_COUNT;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'id', p_id_comprobante,
            'balones_actualizados', v_actualizados
        )
    );
END;
$function$;
