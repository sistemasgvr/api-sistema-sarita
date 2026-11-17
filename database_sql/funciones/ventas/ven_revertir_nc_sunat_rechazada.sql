-- Revierte y elimina (lógicamente) una nota de crédito rechazada por SUNAT
DROP FUNCTION IF EXISTS public.ven_revertir_nc_sunat_rechazada (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.ven_revertir_nc_sunat_rechazada (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_estado_sunat VARCHAR;
    v_rev JSON;
    v_id_pago INTEGER;
    v_anul JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT tc.descripcion, es.nombre
    INTO v_codigo_tipo, v_estado_sunat
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
    WHERE c.id = p_id AND c.estado = 1;

    IF v_codigo_tipo IS NULL THEN
        RETURN json_build_object('ok', FALSE, 'error', 'La nota de crédito no existe o ya fue eliminada');
    END IF;

    IF v_codigo_tipo <> '07' THEN
        RETURN json_build_object('ok', FALSE, 'error', 'Solo aplica a notas de crédito');
    END IF;

    IF COALESCE(v_estado_sunat, '') <> 'RECHAZADO' THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', format('La NC no está RECHAZADA (estado SUNAT: %s)', COALESCE(v_estado_sunat, 'NULL'))
        );
    END IF;

    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, FALSE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos de la NC')
        );
    END IF;

    -- fin_abonar_por_nota_credito abonó la NC a la cuenta por cobrar del
    -- origen al crearla. Rechazada, ese abono no existe: se anula y la
    -- factura vuelve a tener su saldo real.
    FOR v_id_pago IN
        SELECT p.id
        FROM fin_pago p
        INNER JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago AND UPPER(mp.nombre) = 'AJUSTE_NC'
        WHERE p.estado = 1
          AND p.observacion = format('Abono automático por nota de crédito #%s', p_id)
        ORDER BY p.id DESC
    LOOP
        v_anul := fin_anular_pago(v_id_pago, NULL, p_id_usuario_auditoria);
        IF v_anul->>'error' IS NOT NULL THEN
            -- Excepción (no RETURN) para deshacer también la reversión de
            -- inventario hecha arriba y no dejar la NC a medio revertir.
            RAISE EXCEPTION 'No se pudo anular el abono de la NC (pago #%): %', v_id_pago, v_anul->>'error';
        END IF;
    END LOOP;

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

    RETURN json_build_object('ok', TRUE, 'error', NULL, 'id', p_id);
END;
$function$;
