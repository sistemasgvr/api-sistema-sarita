-- Uso interno del API: credenciales PSE con secretos (no exponer por HTTP).
CREATE OR REPLACE FUNCTION gen_obtener_credenciales_facturacion()
RETURNS JSON
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
            e.ruc AS ruc_empresa,
            cs.proveedor_pse,
            cs.pse_habilitado,
            cs.api_base_url,
            cs.api_token,
            cs.api_usuario,
            cs.api_clave,
            COALESCE(NULLIF(TRIM(cs.ruc_emisor), ''), e.ruc) AS ruc_emisor,
            cs.client_id,
            cs.client_secret,
            cs.timeout_ms
        FROM gen_configuracion_sunat cs
        INNER JOIN gen_empresa e ON cs.id_empresa = e.id AND e.estado = 1
        WHERE cs.estado = 1
        ORDER BY cs.id ASC
        LIMIT 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
