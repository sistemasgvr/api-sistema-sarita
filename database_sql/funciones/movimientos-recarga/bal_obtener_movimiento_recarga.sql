CREATE OR REPLACE FUNCTION bal_obtener_movimiento_recarga(p_id INTEGER)
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
            mr.id,
            mr.fecha_salida_almacen,
            mr.id_balon,
            b.codigo_balon,
            mr.id_producto,
            p.nombre AS nombre_producto,
            mr.capacidad,
            mr.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            mr.serie_guia_salida,
            mr.numero_guia_salida,
            mr.serie_guia_ingreso,
            mr.numero_guia_ingreso,
            mr.serie_factura,
            mr.numero_factura,
            mr.id_comprobante,
            mr.fecha_llegada_almacen,
            mr.lote,
            mr.fecha_vencimiento_lote,
            mr.fecha_prueba_hidrostatica,
            mr.id_proveedor,
            prov.razon_social AS nombre_proveedor,
            mr.observacion,
            mr.id_almacen,
            a.nombre AS nombre_almacen,
            mr.estado,
            mr.fecha_creacion,
            mr.fecha_modificacion,
            mr.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            mr.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_movimiento_recarga mr
        INNER JOIN bal_balon b ON mr.id_balon = b.id
        LEFT JOIN pro_producto p ON mr.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON mr.id_unidad_medida = um.id
        LEFT JOIN cli_clientes prov ON mr.id_proveedor = prov.id
        LEFT JOIN gen_almacen a ON mr.id_almacen = a.id
        LEFT JOIN auth_usuarios uc ON mr.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON mr.id_usuario_modificacion = um.id
        WHERE mr.id = p_id AND mr.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
