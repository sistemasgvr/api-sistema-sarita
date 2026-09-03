-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_eliminar_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_eliminar_comprobante(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_eliminar_comprobante(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_rev JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre INTO v_estado_sunat
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
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

    -- Revertir stock, CxC impaga y custodia (préstamo/recarga/alquiler/GRE)
    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, TRUE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos del comprobante')
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

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
