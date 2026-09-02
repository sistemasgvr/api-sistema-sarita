-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gre_obtener_siguiente_numero
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.759Z
DROP FUNCTION IF EXISTS gre_obtener_siguiente_numero(p_serie character varying);

CREATE OR REPLACE FUNCTION gre_obtener_siguiente_numero(p_serie character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_serie VARCHAR(10);
    v_ultimo BIGINT;
    v_siguiente VARCHAR(15);
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(p_serie));
    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria');
    END IF;

    -- UNIQUE(serie, numero) incluye anulados: el siguiente debe considerar todos los estados.
    SELECT COALESCE(MAX(numero::BIGINT), 0)
    INTO v_ultimo
    FROM gre_guia_remision
    WHERE UPPER(TRIM(serie)) = v_serie
      AND numero ~ '^[0-9]+$';

    v_siguiente := LPAD((v_ultimo + 1)::TEXT, 8, '0');

    RETURN json_build_object(
        'serie', v_serie,
        'numero', v_siguiente
    );
END;
$function$
