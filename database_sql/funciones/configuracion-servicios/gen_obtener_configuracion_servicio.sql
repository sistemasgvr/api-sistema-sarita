CREATE OR REPLACE FUNCTION gen_obtener_configuracion_servicio(p_id INTEGER)
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
            cs.codigo,
            cs.nombre,
            cs.usuario,
            (cs.contrasena IS NOT NULL AND TRIM(cs.contrasena) <> '') AS tiene_contrasena,
            cs.email,
            cs.url,
            cs.observacion,
            cs.estado,
            cs.fecha_creacion,
            cs.fecha_modificacion,
            cs.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cs.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_configuracion_servicio cs
        LEFT JOIN auth_usuarios uc ON cs.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cs.id_usuario_modificacion = um.id
        WHERE cs.id = p_id AND cs.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
