CREATE OR REPLACE FUNCTION bal_obtener_movimiento(p_id INTEGER)
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
            m.id,
            m.id_balon,
            b.codigo_balon,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            m.id_cliente,
            c.razon_social AS nombre_cliente,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.fecha_movimiento,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_movimiento m
        INNER JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN cli_clientes c ON m.id_cliente = c.id
        LEFT JOIN gen_almacen ao ON m.id_almacen_origen = ao.id
        LEFT JOIN gen_almacen ad ON m.id_almacen_destino = ad.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
