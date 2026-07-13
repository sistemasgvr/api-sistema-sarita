CREATE OR REPLACE FUNCTION gen_obtener_licencia(p_id INTEGER)
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
            gl.id,
            gl.id_chofer,
            ch.nombres AS chofer_nombres,
            ch.apellido_paterno AS chofer_apellido_paterno,
            ch.apellido_materno AS chofer_apellido_materno,
            ch.numero_documento AS chofer_numero_documento,
            gl.codigo,
            gl.id_tipo_licencia,
            tlo.nombre AS nombre_tipo_licencia,
            gl.id_categoria_licencia,
            clo.nombre AS nombre_categoria_licencia,
            gl.fecha_emision,
            gl.fecha_vencimiento,
            gl.estado,
            gl.fecha_creacion,
            gl.fecha_modificacion,
            gl.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            gl.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_licencia gl
        LEFT JOIN gen_chofer ch ON gl.id_chofer = ch.id
        LEFT JOIN gen_lista_opciones tlo ON gl.id_tipo_licencia = tlo.id
        LEFT JOIN gen_lista_opciones clo ON gl.id_categoria_licencia = clo.id
        LEFT JOIN auth_usuarios uc ON gl.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON gl.id_usuario_modificacion = um.id
        WHERE gl.id = p_id AND gl.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;