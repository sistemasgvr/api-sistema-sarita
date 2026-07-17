DROP FUNCTION IF EXISTS gen_obtener_documento_vencimiento(INTEGER);

CREATE OR REPLACE FUNCTION gen_obtener_documento_vencimiento(p_id INTEGER)
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
            dv.id,
            dv.id_categoria,
            cat.nombre AS nombre_categoria,
            dv.descripcion,
            dv.id_vehiculo,
            v.placa AS vehiculo_placa,
            v.marca AS vehiculo_marca,
            v.modelo AS vehiculo_modelo,
            dv.fecha_vencimiento,
            dv.fecha_renovacion,
            dv.numero_documento,
            dv.observacion,
            dv.id_estado,
            est.nombre AS nombre_estado,
            dv.estado,
            dv.fecha_creacion,
            dv.fecha_modificacion,
            dv.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            dv.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_documento_vencimiento dv
        LEFT JOIN gen_lista_opciones cat ON dv.id_categoria = cat.id
        LEFT JOIN gen_vehiculo v ON dv.id_vehiculo = v.id
        LEFT JOIN gen_lista_opciones est ON dv.id_estado = est.id
        LEFT JOIN auth_usuarios uc ON dv.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON dv.id_usuario_modificacion = um.id
        WHERE dv.id = p_id AND dv.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
