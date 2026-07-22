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
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            cp.razon_social AS nombre_cliente_propietario,
            b.id_cliente_ubicacion,
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
            cv.serie AS serie_comprobante_venta,
            cv.numero AS numero_comprobante_venta,
            cv.fecha AS fecha_comprobante_venta,
            cv_cli.razon_social AS nombre_cliente_comprobante_venta,
            cv.total_importe AS total_comprobante_venta,
            m.id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            cc.fecha AS fecha_comprobante_compra,
            cc_prov.razon_social AS nombre_proveedor_comprobante_compra,
            cc.total_importe AS total_comprobante_compra,
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
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_mantenimiento = tm.id
        LEFT JOIN cli_clientes prov ON m.id_proveedor = prov.id
        LEFT JOIN gen_lista_opciones em ON m.id_estado = em.id
        LEFT JOIN ven_comprobante cv ON m.id_comprobante_venta = cv.id
        LEFT JOIN cli_clientes cv_cli ON cv.id_cliente = cv_cli.id
        LEFT JOIN com_comprobante_compra cc ON m.id_comprobante_compra = cc.id
        LEFT JOIN cli_clientes cc_prov ON cc.id_proveedor = cc_prov.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
