-- Series de retención disponibles para el formulario, con el último correlativo
-- usado y el siguiente a reservar. Mismo criterio que com_crear_retencion:
-- MAX(numero) por empresa + serie contando también las anuladas, para no
-- reutilizar números. Gemela de ven_listar_series_percepcion.
--
-- La serie de retención es R001–R999 (catálogo SUNAT). Si la empresa todavía
-- no emitió ninguna se ofrece R001 con correlativo 00000001.
DROP FUNCTION IF EXISTS com_listar_series_retencion(p_id_empresa integer);

CREATE OR REPLACE FUNCTION com_listar_series_retencion(p_id_empresa integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH usadas AS (
        SELECT
            UPPER(TRIM(r.serie)) AS serie,
            MAX(CASE WHEN r.numero ~ '^[0-9]+$' THEN r.numero::BIGINT END) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM com_retencion r
        WHERE r.serie IS NOT NULL
          AND (p_id_empresa IS NULL OR r.id_empresa = p_id_empresa)
        GROUP BY UPPER(TRIM(r.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE 'R%'
        UNION ALL
        SELECT 'R001', NULL::BIGINT, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = 'R001')
    )
    SELECT json_agg(
        json_build_object(
            'serie', s.serie,
            'ultimo_numero', CASE WHEN s.ultimo IS NULL THEN NULL ELSE LPAD(s.ultimo::TEXT, 8, '0') END,
            'siguiente_numero', LPAD((COALESCE(s.ultimo, 0) + 1)::TEXT, 8, '0'),
            'total', s.total
        )
        ORDER BY s.serie
    )
    INTO v_resultado
    FROM series s;

    RETURN COALESCE(v_resultado, '[]'::json);
END;
$function$;
