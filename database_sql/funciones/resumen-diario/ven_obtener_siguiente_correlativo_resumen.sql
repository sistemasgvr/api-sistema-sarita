-- Function: ven_obtener_siguiente_correlativo_resumen
-- Wave2: advisory lock por fecha para evitar correlativos duplicados en carrera.
DROP FUNCTION IF EXISTS ven_obtener_siguiente_correlativo_resumen(p_fecha date);

CREATE OR REPLACE FUNCTION ven_obtener_siguiente_correlativo_resumen(p_fecha date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ultimo INTEGER;
    v_siguiente VARCHAR(10);
    v_lock_key BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del resumen es obligatoria');
    END IF;

    -- Namespace 872018 + yyyymmdd como segundo entero del advisory lock.
    v_lock_key := to_char(p_fecha, 'YYYYMMDD')::BIGINT;
    PERFORM pg_advisory_xact_lock(872018, v_lock_key::INTEGER);

    SELECT COALESCE(MAX(NULLIF(regexp_replace(correlativo, '\D', '', 'g'), '')::INTEGER), 0)
    INTO v_ultimo
    FROM ven_resumen_diario
    WHERE estado = 1
      AND fecha = p_fecha;

    v_siguiente := LPAD((v_ultimo + 1)::TEXT, 3, '0');

    RETURN json_build_object(
        'fecha', p_fecha,
        'ultimo_correlativo', CASE WHEN v_ultimo = 0 THEN NULL ELSE LPAD(v_ultimo::TEXT, 3, '0') END,
        'correlativo', v_siguiente
    );
END;
$function$;
