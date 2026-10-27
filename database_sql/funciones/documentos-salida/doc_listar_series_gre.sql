-- Lista las series de guía de remisión (V o T según tipo) con su último número
DROP FUNCTION IF EXISTS public.doc_listar_series_gre (p_id_tipo_guia_remision integer);

CREATE OR REPLACE FUNCTION public.doc_listar_series_gre (
  p_id_tipo_guia_remision integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_prefijo VARCHAR;
    v_serie_default VARCHAR;
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_guia_remision IS NOT NULL THEN
        SELECT TRIM(lo.descripcion)
        INTO v_codigo_tipo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_guia_remision;
    END IF;

    v_prefijo := CASE WHEN v_codigo_tipo = '31' THEN 'V' ELSE 'T' END;
    v_serie_default := CASE WHEN v_codigo_tipo = '31' THEN 'V001' ELSE 'T002' END;

    WITH usadas AS (
        SELECT
            UPPER(TRIM(d.serie)) AS serie,
            MAX(NULLIF(REGEXP_REPLACE(d.numero_sunat, '\D', '', 'g'), '')::INTEGER) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM doc_salida d
        WHERE d.serie IS NOT NULL
          AND d.numero_sunat IS NOT NULL
        GROUP BY UPPER(TRIM(d.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE v_prefijo || '%'
        UNION ALL
        SELECT v_serie_default, NULL::INTEGER, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = v_serie_default)
    )
    SELECT json_agg(
        json_build_object(
            'serie', s.serie,
            'ultimo_numero', CASE WHEN s.ultimo IS NULL THEN NULL ELSE LPAD(s.ultimo::TEXT, 8, '0') END,
            'siguiente_numero', LPAD((COALESCE(s.ultimo, 0) + 1)::TEXT, 8, '0'),
            'total', s.total
        )
        ORDER BY CASE WHEN s.serie = v_serie_default THEN 0 ELSE 1 END, s.serie
    )
    INTO v_resultado
    FROM series s;

    RETURN COALESCE(v_resultado, '[]'::json);
END;
$function$;
