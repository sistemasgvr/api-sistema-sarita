-- Elimina (lógicamente) comprobante
DROP FUNCTION IF EXISTS public.ven_eliminar_comprobante (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.ven_eliminar_comprobante (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_rev JSON;
    v_anul JSON;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_os_id INTEGER;
    v_id_almacen_venta INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    PERFORM 1 FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante=p_id AND tipo='CAMBIO_BALON' AND datos->>'tipoOperacion'='CAMBIO') THEN
        RAISE EXCEPTION 'La venta tiene cambios físicos registrados. No se puede eliminar ni restaurar automáticamente su inventario original';
    END IF;

    SELECT es.nombre, c.serie, c.numero, c.id_almacen
    INTO v_estado_sunat, v_serie, v_numero, v_id_almacen_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar un comprobante ya aceptado por SUNAT. Use nota de crédito o comunicación de baja.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque tiene documentos derivados (boleta/factura/nota)'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN age_actividad a ON a.id_doc_salida = d.id AND a.estado = 1
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error',
            'La entrega de esta venta ya fue realizada y los cilindros están en poder del cliente; '
            || 'no se puede anular. Emite una nota de crédito y registra la devolución.'
        );
    END IF;

    FOR v_os_id IN
        SELECT d.id
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND ec.nombre <> 'ANULADA'
    LOOP
        v_anul := doc_anular_salida(
            v_os_id,
            format('Venta %s-%s anulada', COALESCE(v_serie, ''), COALESCE(v_numero, p_id::text)),
            p_id_usuario_auditoria
        );
        IF v_anul->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_anul->>'error';
        END IF;
    END LOOP;

    UPDATE bal_balon b
    SET id_estado_balon = lo_disp.id,
        id_almacen = COALESCE(b.id_almacen, v_id_almacen_venta),
        id_cliente_ubicacion = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM ven_comprobante_detalle d
    CROSS JOIN LATERAL (
        SELECT lo.id
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1
    ) lo_disp
    CROSS JOIN gen_lista_opciones eb
    WHERE d.id_comprobante = p_id
      AND d.estado = 1
      AND d.id_balon = b.id
      AND eb.id = b.id_estado_balon
      AND b.estado = 1
      AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
      AND lo_disp.id IS NOT NULL
      AND UPPER(TRIM(eb.nombre)) IN ('PENDIENTE_ENVIO', 'EN_PODER_CLIENTE');

    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, TRUE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RAISE EXCEPTION '%', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos del comprobante');
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante_pago
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', SQLERRM);
END;
$function$;
