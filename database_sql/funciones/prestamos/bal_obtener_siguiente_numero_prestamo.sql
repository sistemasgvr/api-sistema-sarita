-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_siguiente_numero_prestamo
-- Overloads: 1
--
-- Actualizada por database_sql/migraciones/20260905_movimientos_orden_garantia_dueno_y_numero_prestamo.sql:
-- nueva: correlativo PRE-<anio>-<3 digitos>.
DROP FUNCTION IF EXISTS bal_obtener_siguiente_numero_prestamo(p_anio integer);

CREATE OR REPLACE FUNCTION bal_obtener_siguiente_numero_prestamo(p_anio integer DEFAULT NULL::integer)
 RETURNS json
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
    v_prefijo := 'PRE-' || v_anio::TEXT || '-';

    -- Se mira el mayor correlativo ya usado en el anio, incluidos los prestamos
    -- cerrados o anulados, para no reutilizar un numero.
    SELECT COALESCE(
        MAX(
            NULLIF(
                REGEXP_REPLACE(UPPER(TRIM(numero_prestamo)), '^PRE-' || v_anio::TEXT || '-', ''),
                ''
            )::INTEGER
        ),
        0
    )
    INTO v_ultimo
    FROM bal_prestamo
    WHERE UPPER(TRIM(numero_prestamo)) ~ ('^PRE-' || v_anio::TEXT || '-[0-9]+$');

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
            'error', 'No se pudo calcular el correlativo de prestamo',
            'numero', NULL
        );
END;
$function$;
