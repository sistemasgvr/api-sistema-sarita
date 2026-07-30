CREATE OR REPLACE FUNCTION bal_obtener_alquiler_detalle(p_id INTEGER)
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
            ad.id,
            ad.id_alquiler,
            al.numero_alquiler,
            ad.id_balon,
            b.codigo_balon,
            ad.fecha_devolucion,
            ad.estado,
            ad.fecha_creacion,
            ad.fecha_modificacion,
            ad.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ad.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_alquiler_detalle ad
        INNER JOIN bal_alquiler al ON ad.id_alquiler = al.id
        INNER JOIN bal_balon b ON ad.id_balon = b.id
        LEFT JOIN auth_usuarios uc ON ad.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ad.id_usuario_modificacion = um.id
        WHERE ad.id = p_id AND ad.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
