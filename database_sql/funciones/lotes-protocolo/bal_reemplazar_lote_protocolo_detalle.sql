-- Function: bal_reemplazar_lote_protocolo_detalle
-- Fase 5 — punto único de escritura del detalle de una ficha ICP (pruebas y
-- envases). Lo usan crear y actualizar, para que ambas dejen exactamente el
-- mismo estado y la regla de "match por número de serie" viva en un solo sitio.
--
-- p_pruebas / p_envases NULL = no tocar ese bloque. Un array vacío sí lo vacía.
DROP FUNCTION IF EXISTS bal_reemplazar_lote_protocolo_detalle(p_id_lote_protocolo integer, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_reemplazar_lote_protocolo_detalle(p_id_lote_protocolo integer, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_pruebas INTEGER := 0;
    v_total_envases INTEGER := 0;
    v_vinculados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_pruebas IS NOT NULL THEN
        UPDATE bal_lote_protocolo_prueba
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_lote_protocolo = p_id_lote_protocolo AND estado = 1;

        INSERT INTO bal_lote_protocolo_prueba (
            id_lote_protocolo, orden, prueba, especificacion, resultado,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_lote_protocolo,
            COALESCE((x->>'orden')::INT, ordinalidad::INT),
            NULLIF(TRIM(x->>'prueba'), ''),
            NULLIF(TRIM(x->>'especificacion'), ''),
            NULLIF(TRIM(x->>'resultado'), ''),
            1, p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM json_array_elements(p_pruebas) WITH ORDINALITY AS a(x, ordinalidad)
        WHERE NULLIF(TRIM(x->>'prueba'), '') IS NOT NULL;

        GET DIAGNOSTICS v_total_pruebas = ROW_COUNT;
    END IF;

    IF p_envases IS NOT NULL THEN
        UPDATE bal_lote_protocolo_envase
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_lote_protocolo = p_id_lote_protocolo AND estado = 1;

        -- El envase puede venir como objeto {serieEnvase} o como serie suelta:
        -- la relación del PDF es una lista de series, no de objetos.
        INSERT INTO bal_lote_protocolo_envase (
            id_lote_protocolo, serie_envase, id_balon,
            estado, id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_lote_protocolo,
            s.serie,
            (
                SELECT b.id
                FROM bal_balon b
                WHERE b.estado = 1
                  AND UPPER(TRIM(COALESCE(b.numero_serie, ''))) = UPPER(s.serie)
                ORDER BY b.id
                LIMIT 1
            ),
            1, p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM (
            SELECT DISTINCT UPPER(TRIM(COALESCE(x->>'serieEnvase', x->>'serie_envase', x#>>'{}'))) AS serie
            FROM json_array_elements(p_envases) AS a(x)
        ) s
        WHERE NULLIF(s.serie, '') IS NOT NULL
        ON CONFLICT (id_lote_protocolo, serie_envase) DO UPDATE
        SET estado = 1,
            id_balon = EXCLUDED.id_balon,
            id_usuario_modificacion = EXCLUDED.id_usuario_modificacion,
            fecha_modificacion = NOW();

        GET DIAGNOSTICS v_total_envases = ROW_COUNT;

        SELECT COUNT(*)::INT INTO v_vinculados
        FROM bal_lote_protocolo_envase e
        WHERE e.id_lote_protocolo = p_id_lote_protocolo
          AND e.estado = 1
          AND e.id_balon IS NOT NULL;
    END IF;

    RETURN json_build_object(
        'total_pruebas', v_total_pruebas,
        'total_envases', v_total_envases,
        'total_envases_vinculados', v_vinculados
    );
END;
$function$;
