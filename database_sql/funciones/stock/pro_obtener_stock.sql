CREATE OR REPLACE FUNCTION pro_obtener_stock(p_id INTEGER)
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
            s.id,
            s.id_almacen,
            a.nombre AS nombre_almacen,
            a.id_sucursal,
            suc.nombre AS nombre_sucursal,
            s.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            s.stock,
            s.stock_minimo,
            (s.stock <= s.stock_minimo) AS bajo_minimo,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_stock s
        INNER JOIN gen_almacen a ON s.id_almacen = a.id
        INNER JOIN gen_sucursal suc ON a.id_sucursal = suc.id
        INNER JOIN pro_producto p ON s.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON s.id_usuario_modificacion = um2.id
        WHERE s.id = p_id AND s.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
