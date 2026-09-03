-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_obtener_siguiente_correlativo_resumen
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_obtener_siguiente_correlativo_resumen(p_fecha date);

CREATE OR REPLACE FUNCTION ven_obtener_siguiente_correlativo_resumen(p_fecha date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_ultimo INTEGER;
    v_siguiente VARCHAR(10);
BEGIN
    SET TIME ZONE 'America/Lima';

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
