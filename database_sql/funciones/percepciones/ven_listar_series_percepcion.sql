-- Series de percepción disponibles para el formulario, con el último
-- correlativo usado y el siguiente a reservar. Mismo criterio que
-- ven_crear_percepcion: MAX(numero) por empresa + serie contando también las
-- anuladas, para no reutilizar números. Equivale a doc_listar_series_gre.
--
-- La serie de percepción es P001–P999 (catálogo SUNAT). Si la empresa todavía
-- no emitió ninguna se ofrece P001 con correlativo 00000001.
DROP FUNCTION IF EXISTS ven_listar_series_percepcion(p_id_empresa integer);

CREATE OR REPLACE FUNCTION ven_listar_series_percepcion(p_id_empresa integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH usadas AS (
        SELECT
            UPPER(TRIM(p.serie)) AS serie,
            MAX(CASE WHEN p.numero ~ '^[0-9]+$' THEN p.numero::BIGINT END) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM ven_percepcion p
        WHERE p.serie IS NOT NULL
          AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa)
        GROUP BY UPPER(TRIM(p.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE 'P%'
        UNION ALL
        SELECT 'P001', NULL::BIGINT, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = 'P001')
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
