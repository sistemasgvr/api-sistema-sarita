-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_obtener_siguiente_numero
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_obtener_siguiente_numero(p_id_tipo_comprobante integer, p_serie character varying);

CREATE OR REPLACE FUNCTION ven_obtener_siguiente_numero(p_id_tipo_comprobante integer, p_serie character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_serie VARCHAR;
    v_ultimo BIGINT;
    v_siguiente VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_serie := UPPER(TRIM(p_serie));

    IF p_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El tipo de comprobante es obligatorio', 'numero', NULL);
    END IF;

    IF v_serie IS NULL OR v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'numero', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o está inactivo', 'numero', NULL);
    END IF;

    -- UNIQUE(serie, numero) incluye anulados: el siguiente debe considerar todos los estados.
    SELECT COALESCE(MAX(numero::BIGINT), 0) INTO v_ultimo
    FROM ven_comprobante
    WHERE UPPER(TRIM(serie)) = v_serie
      AND numero ~ '^[0-9]+$';

    v_siguiente := LPAD((v_ultimo + 1)::TEXT, 8, '0');

    RETURN json_build_object(
        'serie', v_serie,
        'id_tipo_comprobante', p_id_tipo_comprobante,
        'ultimo_numero', CASE WHEN v_ultimo = 0 THEN NULL ELSE LPAD(v_ultimo::TEXT, 8, '0') END,
        'numero', v_siguiente
    );
END;
$function$;
