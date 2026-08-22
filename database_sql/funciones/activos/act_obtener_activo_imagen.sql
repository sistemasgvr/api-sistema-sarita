CREATE OR REPLACE FUNCTION act_obtener_activo_imagen(p_id INTEGER)
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
            ai.id,
            ai.id_activo,
            ai.id_archivo,
            a.nombre_original,
            a.nombre_almacenado,
            a.ruta,
            a.bucket,
            a.mime_type,
            a.extension,
            a.tamanio_bytes,
            ai.orden,
            ai.es_principal,
            ai.estado,
            ai.fecha_creacion,
            ai.fecha_modificacion,
            ai.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ai.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM act_activo_imagen ai
        INNER JOIN gen_archivo a ON ai.id_archivo = a.id
        LEFT JOIN auth_usuarios uc ON ai.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ai.id_usuario_modificacion = um.id
        WHERE ai.id = p_id AND ai.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
