-- Series de guía de remisión disponibles para el modal "Convertir a GRE", con
-- el último correlativo usado y el siguiente a reservar (mismo criterio que
-- doc_convertir_a_gre: MAX(numero_sunat) por serie, incluyendo anuladas, para
-- no reutilizar números). Equivale a ven_obtener_siguiente_numero de boletas,
-- pero devolviendo todas las series ya usadas para elegirlas en un select.
--
-- El tipo de guía define el prefijo SUNAT: 09 GRE Remitente → T###,
-- 31 GRE Transportista → V###. Si aún no hay ninguna serie con ese prefijo se
-- ofrece la serie por defecto (T001 / V001) con correlativo 00000001.
DROP FUNCTION IF EXISTS doc_listar_series_gre(p_id_tipo_guia_remision integer);

CREATE OR REPLACE FUNCTION doc_listar_series_gre(p_id_tipo_guia_remision integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_prefijo VARCHAR;
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_guia_remision IS NOT NULL THEN
        SELECT TRIM(lo.descripcion)
        INTO v_codigo_tipo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_guia_remision;
    END IF;

    -- Sin tipo (o tipo desconocido) se asume remitente, el caso habitual.
    v_prefijo := CASE WHEN v_codigo_tipo = '31' THEN 'V' ELSE 'T' END;

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
        SELECT v_prefijo || '001', NULL::INTEGER, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = v_prefijo || '001')
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
