CREATE OR REPLACE FUNCTION bal_obtener_prestamo(p_id INTEGER)
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
            pr.id,
            pr.numero_prestamo,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            c.razon_social AS nombre_cliente,
            pr.id_proveedor,
            prov.razon_social AS nombre_proveedor,
            pr.id_almacen,
            a.nombre AS nombre_almacen,
            pr.fecha_salida,
            pr.fecha_retorno_pactada,
            pr.fecha_retorno_real,
            pr.titulo,
            pr.observacion,
            pr.id_estado,
            ep.nombre AS nombre_estado,
            pr.id_comprobante_venta,
            cv.serie AS serie_comprobante_venta,
            cv.numero AS numero_comprobante_venta,
            cv.fecha AS fecha_comprobante_venta,
            cv_cli.razon_social AS nombre_cliente_comprobante_venta,
            cv.total_importe AS total_comprobante_venta,
            pr.id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            cc.fecha AS fecha_comprobante_compra,
            cc_prov.razon_social AS nombre_proveedor_comprobante_compra,
            cc.total_importe AS total_comprobante_compra,
            pr.estado,
            pr.fecha_creacion,
            pr.fecha_modificacion,
            pr.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            pr.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = pr.id AND pd.estado = 1
            ) AS total_detalles
        FROM bal_prestamo pr
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN cli_clientes prov ON pr.id_proveedor = prov.id
        LEFT JOIN gen_almacen a ON pr.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ep ON pr.id_estado = ep.id
        LEFT JOIN ven_comprobante cv ON pr.id_comprobante_venta = cv.id
        LEFT JOIN cli_clientes cv_cli ON cv.id_cliente = cv_cli.id
        LEFT JOIN com_comprobante_compra cc ON pr.id_comprobante_compra = cc.id
        LEFT JOIN cli_clientes cc_prov ON cc.id_proveedor = cc_prov.id
        LEFT JOIN auth_usuarios uc ON pr.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pr.id_usuario_modificacion = um.id
        WHERE pr.id = p_id AND pr.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
