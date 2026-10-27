-- Obtiene la configuración de APIsPERU sin secretos (solo indica si existen)
DROP FUNCTION IF EXISTS public.gen_obtener_facturacion_apisperu ();

CREATE OR REPLACE FUNCTION public.gen_obtener_facturacion_apisperu () RETURNS json LANGUAGE plpgsql AS $function$
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
            e.nombre_comercial,
            cs.apisperu_habilitado AS habilitado,
            cs.apisperu_url AS url,
            cs.apisperu_timeout_ms AS timeout_ms,
            cs.client_id_gre AS client_id,
            (cs.apisperu_token IS NOT NULL AND TRIM(cs.apisperu_token) <> '') AS tiene_token,
            (cs.client_secret_gre IS NOT NULL AND TRIM(cs.client_secret_gre) <> '') AS tiene_client_secret,
            cs.estado,
            cs.fecha_creacion,
            cs.fecha_modificacion
        FROM gen_configuracion_sunat cs
        INNER JOIN gen_empresa e ON e.id = cs.id_empresa
        WHERE cs.estado = 1
        ORDER BY cs.id
        LIMIT 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
