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
            pr.id_comprobante_compra,
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
        LEFT JOIN auth_usuarios uc ON pr.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pr.id_usuario_modificacion = um.id
        WHERE pr.id = p_id AND pr.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
