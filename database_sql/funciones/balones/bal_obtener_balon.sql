CREATE OR REPLACE FUNCTION bal_obtener_balon(p_id INTEGER)
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
            b.id,
            b.codigo_balon,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            cu.razon_social AS nombre_cliente_ubicacion,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            cp.razon_social AS nombre_cliente_propietario,
            b.id_referencia,
            ref.nombre AS nombre_referencia,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.fecha_ultima_prueba_hidrostatica,
            b.vigencia_prueba_hidrostatica_anios,
            b.fecha_proxima_prueba_hidrostatica,
            b.fecha_fabricacion,
            b.numero_recepcion,
            b.presion_actual,
            b.observacion,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion,
            b.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            b.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_balon b
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN gen_lista_opciones ref ON b.id_referencia = ref.id
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN auth_usuarios uc ON b.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON b.id_usuario_modificacion = um.id
        WHERE b.id = p_id AND b.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
