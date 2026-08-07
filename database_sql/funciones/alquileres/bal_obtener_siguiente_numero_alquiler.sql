CREATE OR REPLACE FUNCTION bal_obtener_siguiente_numero_alquiler(
    p_anio INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_prefijo VARCHAR;
    v_ultimo INTEGER;
    v_siguiente VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_prefijo := 'ALQ-' || v_anio::TEXT || '-';

    SELECT COALESCE(
        MAX(
            NULLIF(
                REGEXP_REPLACE(UPPER(TRIM(numero_alquiler)), '^ALQ-' || v_anio::TEXT || '-', ''),
                ''
            )::INTEGER
        ),
        0
    )
    INTO v_ultimo
    FROM bal_alquiler
    WHERE UPPER(TRIM(numero_alquiler)) ~ ('^ALQ-' || v_anio::TEXT || '-[0-9]+$');

    v_siguiente := v_prefijo || LPAD((v_ultimo + 1)::TEXT, 3, '0');

    RETURN json_build_object(
        'error', NULL,
        'anio', v_anio,
        'ultimo', CASE WHEN v_ultimo = 0 THEN NULL ELSE v_prefijo || LPAD(v_ultimo::TEXT, 3, '0') END,
        'numero', v_siguiente
    );
EXCEPTION
    WHEN others THEN
        RETURN json_build_object(
            'error', 'No se pudo calcular el correlativo de alquiler',
            'numero', NULL
        );
END;
$function$;
