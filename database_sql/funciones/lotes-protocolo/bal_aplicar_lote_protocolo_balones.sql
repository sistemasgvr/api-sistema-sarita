-- Function: bal_aplicar_lote_protocolo_balones
-- Fase 5 — marca una ficha ICP como la vigente de un conjunto de cilindros.
-- Es el punto de enganche del ingreso por compra (apunte 2.a.ii "al momento de
-- su ingreso") y del retorno de una recarga en planta externa.
--
-- p_id_balones NULL = aplicar a todos los cilindros que la propia relación de
-- envases aprobados ya emparejó por número de serie.
-- p_id_doc_salida (Wave 3): opcional; si viene, escribe doc_salida.id_lote_protocolo
-- para enganchar la ficha a la orden de salida que la originó.
DROP FUNCTION IF EXISTS bal_aplicar_lote_protocolo_balones(p_id_lote_protocolo integer, p_id_balones json, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS bal_aplicar_lote_protocolo_balones(p_id_lote_protocolo integer, p_id_balones json, p_id_usuario_auditoria integer, p_id_doc_salida integer);

CREATE OR REPLACE FUNCTION bal_aplicar_lote_protocolo_balones(p_id_lote_protocolo integer, p_id_balones json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_doc_salida integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ids INTEGER[];
    v_aplicados INTEGER := 0;
    v_vinculados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_lote_protocolo WHERE id = p_id_lote_protocolo AND estado = 1) THEN
        RETURN json_build_object('error', 'Ficha de lote y protocolo no encontrada', 'registro', NULL);
    END IF;

    IF p_id_balones IS NULL THEN
        SELECT ARRAY_AGG(DISTINCT e.id_balon)
        INTO v_ids
        FROM bal_lote_protocolo_envase e
        WHERE e.id_lote_protocolo = p_id_lote_protocolo
          AND e.estado = 1
          AND e.id_balon IS NOT NULL;
    ELSE
        SELECT ARRAY_AGG(DISTINCT (x#>>'{}')::INT)
        INTO v_ids
        FROM json_array_elements(p_id_balones) AS a(x)
        WHERE NULLIF(x#>>'{}', '') IS NOT NULL;
    END IF;

    v_ids := COALESCE(v_ids, ARRAY[]::INTEGER[]);

    IF array_length(v_ids, 1) IS NULL THEN
        -- Sin cilindros aún: igual se puede enganchar la ficha a la orden.
        IF p_id_doc_salida IS NOT NULL THEN
            UPDATE doc_salida
            SET id_lote_protocolo = p_id_lote_protocolo,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = p_id_doc_salida AND estado = 1;
        END IF;

        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object(
                'id_lote_protocolo', p_id_lote_protocolo,
                'balones_aplicados', 0,
                'envases_vinculados', 0,
                'id_doc_salida', p_id_doc_salida
            )
        );
    END IF;

    -- Un cilindro que no estaba en la relación de envases pero sí se recargó
    -- con este lote entra a la relación: la ficha debe reflejar a qué envases
    -- se aplicó realmente. Sin número de serie se usa el código del cilindro.
    INSERT INTO bal_lote_protocolo_envase (
        id_lote_protocolo, serie_envase, id_balon,
        estado, id_usuario_creacion, id_usuario_modificacion
    )
    SELECT
        p_id_lote_protocolo,
        UPPER(TRIM(COALESCE(NULLIF(TRIM(b.numero_serie), ''), b.codigo_balon))),
        b.id,
        1, p_id_usuario_auditoria, p_id_usuario_auditoria
    FROM bal_balon b
    WHERE b.id = ANY(v_ids) AND b.estado = 1
    ON CONFLICT (id_lote_protocolo, serie_envase) DO UPDATE
    SET estado = 1,
        id_balon = EXCLUDED.id_balon,
        id_usuario_modificacion = EXCLUDED.id_usuario_modificacion,
        fecha_modificacion = NOW();

    GET DIAGNOSTICS v_vinculados = ROW_COUNT;

    UPDATE bal_balon
    SET id_lote_protocolo_vigente = p_id_lote_protocolo,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = ANY(v_ids) AND estado = 1;

    GET DIAGNOSTICS v_aplicados = ROW_COUNT;

    IF p_id_doc_salida IS NOT NULL THEN
        UPDATE doc_salida
        SET id_lote_protocolo = p_id_lote_protocolo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;
    END IF;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'id_lote_protocolo', p_id_lote_protocolo,
            'balones_aplicados', v_aplicados,
            'envases_vinculados', v_vinculados,
            'id_doc_salida', p_id_doc_salida
        )
    );
END;
$function$;
