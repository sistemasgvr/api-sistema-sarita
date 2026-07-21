CREATE OR REPLACE FUNCTION pro_listar_producto_imagenes(
    p_id_producto INTEGER,
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto IS NULL THEN
        RETURN json_build_object(
            'error', 'El id_producto es obligatorio',
            'registros', '[]'::JSON,
            'total', 0
        );
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM pro_producto_imagen pi
    WHERE pi.estado = 1
      AND pi.id_producto = p_id_producto;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
        WHERE pi.estado = 1
          AND pi.id_producto = p_id_producto
        ORDER BY pi.es_principal DESC, pi.orden ASC, pi.id ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
