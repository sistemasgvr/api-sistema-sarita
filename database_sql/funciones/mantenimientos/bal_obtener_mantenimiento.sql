CREATE OR REPLACE FUNCTION bal_obtener_mantenimiento(p_id INTEGER)
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
            m.id_tipo_mantenimiento,
            tm.nombre AS nombre_tipo_mantenimiento,
            m.fecha_ingreso,
            m.fecha_salida,
            m.descripcion,
            m.costo,
            m.es_externo,
            m.id_proveedor,
            prov.razon_social AS nombre_proveedor,
            m.id_estado,
            em.nombre AS nombre_estado,
            m.id_comprobante_venta,
            m.id_comprobante_compra,
            m.observacion,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_mantenimiento m
        INNER JOIN bal_balon b ON m.id_balon = b.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_mantenimiento = tm.id
        LEFT JOIN cli_clientes prov ON m.id_proveedor = prov.id
        LEFT JOIN gen_lista_opciones em ON m.id_estado = em.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
