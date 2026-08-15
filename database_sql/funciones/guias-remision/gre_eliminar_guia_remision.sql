CREATE OR REPLACE FUNCTION gre_eliminar_guia_remision(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_orden_numero VARCHAR;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM gre_guia_remision WHERE id = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    SELECT es.nombre INTO v_estado_sunat
    FROM gre_guia_remision g
    LEFT JOIN gen_lista_opciones es ON g.id_estado_sunat = es.id
    WHERE g.id = p_id AND g.estado = 1;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'error', 'No se puede eliminar una guía aceptada por SUNAT',
            'eliminado', FALSE,
            'id', p_id
        );
    END IF;

    SELECT rp.numero
    INTO v_orden_numero
    FROM bal_recarga_planta rp
    WHERE rp.estado = 1
      AND (rp.id_guia_salida = p_id OR rp.id_guia_retorno = p_id)
    ORDER BY rp.id
    LIMIT 1;

    IF v_orden_numero IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            format(
                'No se puede eliminar: la guía está vinculada a la orden de recarga %s',
                v_orden_numero
            ),
            'eliminado',
            FALSE,
            'id',
            p_id
        );
    END IF;

    v_rev := bal_revertir_salidas_guia_remision(p_id, NULL, p_id_usuario_auditoria);
    IF v_rev->>'error' IS NOT NULL THEN
        RETURN json_build_object(
            'error', v_rev->>'error',
            'eliminado', FALSE,
            'id', p_id
        );
    END IF;

    UPDATE gre_guia_remision
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    UPDATE gre_guia_remision_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_guia_remision = p_id AND estado = 1;

    UPDATE gre_documentos_referencia
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_guia_remision = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
