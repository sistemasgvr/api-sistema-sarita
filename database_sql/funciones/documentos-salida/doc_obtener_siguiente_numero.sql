-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_obtener_siguiente_numero
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_obtener_siguiente_numero(p_id_sucursal integer, p_fecha date);

CREATE OR REPLACE FUNCTION doc_obtener_siguiente_numero(p_id_sucursal integer, p_fecha date DEFAULT NULL::date)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_prefijo VARCHAR;
    v_siguiente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_sucursal IS NULL THEN
        RAISE EXCEPTION 'La sucursal es obligatoria para numerar el documento de salida';
    END IF;

    v_anio := EXTRACT(YEAR FROM COALESCE(p_fecha, CURRENT_DATE))::INTEGER;
    v_prefijo := 'OS-' || LPAD(p_id_sucursal::TEXT, 2, '0') || '-' || v_anio::TEXT || '-';

    -- Se toma el mayor correlativo ya usado con ese prefijo (incluye anulados, para no
    -- reutilizar números) y se avanza uno.
    SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(RIGHT(d.numero, 6), '\D', '', 'g'), '')::INTEGER), 0) + 1
    INTO v_siguiente
    FROM doc_salida d
    WHERE d.numero LIKE v_prefijo || '%';

    RETURN v_prefijo || LPAD(v_siguiente::TEXT, 6, '0');
END;
$function$;
