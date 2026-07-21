CREATE OR REPLACE FUNCTION pro_obtener_producto_imagen(p_id INTEGER)
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
            pi.id,
            pi.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            pi.id_archivo,
            a.nombre_original,
            a.nombre_almacenado,
            a.ruta,
            a.bucket,
            a.mime_type,
            a.extension,
            a.tamanio_bytes,
            pi.orden,
            pi.es_principal,
            pi.estado,
            pi.fecha_creacion,
            pi.fecha_modificacion,
            pi.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            pi.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM pro_producto_imagen pi
        INNER JOIN pro_producto p ON pi.id_producto = p.id
        INNER JOIN gen_archivo a ON pi.id_archivo = a.id
        LEFT JOIN auth_usuarios uc ON pi.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pi.id_usuario_modificacion = um.id
        WHERE pi.id = p_id AND pi.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
