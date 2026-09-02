-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_facturacion_apisperu_secreto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.750Z
DROP FUNCTION IF EXISTS gen_obtener_facturacion_apisperu_secreto();

CREATE OR REPLACE FUNCTION gen_obtener_facturacion_apisperu_secreto()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            cs.id,
            cs.id_empresa,
            e.ruc AS ruc_emisor,
            cs.apisperu_habilitado AS habilitado,
            cs.apisperu_url AS url,
            cs.apisperu_timeout_ms AS timeout_ms,
            cs.apisperu_token AS token,
            cs.client_id_gre AS client_id,
            cs.client_secret_gre AS client_secret,
            cs.estado
        FROM gen_configuracion_sunat cs
        INNER JOIN gen_empresa e ON e.id = cs.id_empresa
        WHERE cs.estado = 1
        ORDER BY cs.id
        LIMIT 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
