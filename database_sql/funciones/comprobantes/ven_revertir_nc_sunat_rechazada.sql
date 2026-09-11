-- Function: ven_revertir_nc_sunat_rechazada
--
-- Creada por database_sql/migraciones/20260911_w1_nc_planta_devolver.sql:
-- cuando SUNAT rechaza una nota de crédito, revierte el kardex/efectos de la
-- NC y la soft-borra (estado=0) para liberar el tope de cantidades y permitir
-- emitir otra.
DROP FUNCTION IF EXISTS ven_revertir_nc_sunat_rechazada(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_revertir_nc_sunat_rechazada(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_estado_sunat VARCHAR;
    v_rev JSON;
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
