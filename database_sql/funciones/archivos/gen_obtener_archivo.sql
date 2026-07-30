CREATE OR REPLACE FUNCTION gen_obtener_archivo(p_id INTEGER)
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
            a.id,
            a.nombre_original,
            a.nombre_almacenado,
            a.ruta,
            a.bucket,
            a.mime_type,
            a.extension,
            a.tamanio_bytes,
            a.id_empresa,
            e.nombre_comercial AS nombre_empresa,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion,
            a.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            a.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_archivo a
        LEFT JOIN gen_empresa e ON a.id_empresa = e.id
        LEFT JOIN auth_usuarios uc ON a.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON a.id_usuario_modificacion = um.id
        WHERE a.id = p_id AND a.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
