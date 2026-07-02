CREATE OR REPLACE FUNCTION pro_obtener_movimiento(p_id INTEGER)
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
            m.fecha,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            m.id_almacen,
            a.nombre AS nombre_almacen,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.cantidad,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_ref,
            m.id_tipo_documento_ref,
            tdr.nombre AS nombre_tipo_documento_ref,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM pro_movimientos m
        INNER JOIN pro_producto p ON m.id_producto = p.id
        INNER JOIN gen_almacen a ON m.id_almacen = a.id
        LEFT JOIN gen_lista_opciones tm ON m.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tdr ON m.id_tipo_documento_ref = tdr.id
        LEFT JOIN auth_usuarios uc ON m.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON m.id_usuario_modificacion = um.id
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
