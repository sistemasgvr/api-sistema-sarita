DROP FUNCTION IF EXISTS cli_obtener_baja_cliente;

CREATE OR REPLACE FUNCTION cli_obtener_baja_cliente(p_id INTEGER)
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
            bc.id,
            bc.tipo_solicitud,
            bc.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            bc.id_motivo_baja,
            mb.nombre AS nombre_motivo_baja,
            bc.fecha_baja,
            bc.id_usuario_solicita,
            us.nombre AS nombre_usuario_solicita,
            bc.id_usuario_autoriza,
            ua.nombre AS nombre_usuario_autoriza,
            bc.fecha_autorizacion,
            bc.id_estado_aprobacion,
            ea.nombre AS nombre_estado_aprobacion,
            bc.motivo_detalle,
            bc.estado,
            bc.fecha_creacion,
            bc.fecha_modificacion,
            bc.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            bc.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM cli_baja_cliente bc
        INNER JOIN cli_clientes c ON bc.id_cliente = c.id
        LEFT JOIN gen_lista_opciones mb ON bc.id_motivo_baja = mb.id
        LEFT JOIN gen_lista_opciones ea ON bc.id_estado_aprobacion = ea.id
        LEFT JOIN auth_usuarios us ON bc.id_usuario_solicita = us.id
        LEFT JOIN auth_usuarios ua ON bc.id_usuario_autoriza = ua.id
        LEFT JOIN auth_usuarios uc ON bc.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON bc.id_usuario_modificacion = um.id
        WHERE bc.id = p_id AND bc.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
