-- Calcula el siguiente número de documento de salida (OS) por sucursal y año
DROP FUNCTION IF EXISTS public.doc_obtener_siguiente_numero (p_id_sucursal integer, p_fecha date);

CREATE OR REPLACE FUNCTION public.doc_obtener_siguiente_numero (
  p_id_sucursal integer,
  p_fecha date DEFAULT NULL::date
) RETURNS character varying LANGUAGE plpgsql AS $function$
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

    PERFORM pg_advisory_xact_lock(872016, hashtext(v_prefijo));

    SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(RIGHT(d.numero, 6), '\D', '', 'g'), '')::INTEGER), 0) + 1
    INTO v_siguiente
    FROM doc_salida d
    WHERE d.numero LIKE v_prefijo || '%';

    RETURN v_prefijo || LPAD(v_siguiente::TEXT, 6, '0');
END;
$function$;
