CREATE OR REPLACE FUNCTION gen_obtener_chofer(p_id INTEGER)
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
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.apellido_paterno,
            ch.apellido_materno,
            ch.nombres,
            ch.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            ch.numero_documento,
            ch.brevete,
            ch.telefono,
            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN gen_lista_opciones td ON ch.id_tipo_documento = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id
        WHERE ch.id = p_id AND ch.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
