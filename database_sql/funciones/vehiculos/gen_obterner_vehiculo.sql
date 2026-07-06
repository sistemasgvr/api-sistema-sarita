DROP FUNCTION IF EXISTS gen_obtener_vehiculo(INTEGER);

CREATE OR REPLACE FUNCTION gen_obtener_vehiculo(p_id INTEGER)
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
            v.id,
            v.id_cliente,
            COALESCE(c.razon_social, c.nombres) AS nombre_cliente,
            v.id_tipo_vehiculo,
            tv.nombre AS nombre_tipo_vehiculo,
            v.placa,
            v.placa2,
            v.marca,
            v.marca2,
            v.modelo,
            v.anio,
            v.color,
            v.certificado_inscripcion,
            v.certificado2,
            v.estado,
            v.fecha_creacion,
            v.fecha_modificacion,
            v.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            v.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_vehiculo v
        LEFT JOIN cli_clientes c ON v.id_cliente = c.id
        LEFT JOIN gen_lista_opciones tv ON v.id_tipo_vehiculo = tv.id
        LEFT JOIN auth_usuarios uc ON v.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON v.id_usuario_modificacion = um.id
        WHERE v.id = p_id AND v.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;