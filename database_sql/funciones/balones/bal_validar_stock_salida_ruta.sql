-- Sumar todos los cilindros y productos adicionales antes de descontar inventario.
CREATE OR REPLACE FUNCTION public.bal_validar_stock_salida_ruta(p_id integer, p_bloquear boolean DEFAULT FALSE)
RETURNS void LANGUAGE plpgsql AS $function$
DECLARE
    v_almacen INTEGER;
    v_nombre_almacen VARCHAR;
    v_req RECORD;
    v_stock NUMERIC;
BEGIN
    SELECT r.id_almacen, a.nombre INTO v_almacen, v_nombre_almacen
    FROM bal_ruta_pueblo r JOIN gen_almacen a ON a.id = r.id_almacen
    WHERE r.id = p_id AND r.estado = 1 AND r.control_gas_manual;
    IF NOT FOUND THEN RAISE EXCEPTION 'Ruta manual no encontrada'; END IF;
    FOR v_req IN
        SELECT p.id, p.nombre, COALESCE(um.nombre, 'unidades') AS unidad, SUM(q.cantidad) AS cantidad
        FROM (
            SELECT d.id_producto_gas AS id_producto, d.m3_salida AS cantidad
            FROM bal_ruta_pueblo_detalle d WHERE d.id_ruta_pueblo = p_id AND d.estado = 1
            UNION ALL
            SELECT d.id_producto, d.cantidad
            FROM bal_ruta_pueblo_detalle_producto d WHERE d.id_ruta_pueblo = p_id AND d.estado = 1
        ) q
        JOIN pro_producto p ON p.id = q.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        WHERE p.afecta_stock
        GROUP BY p.id, p.nombre, um.nombre
        ORDER BY p.id
    LOOP
        v_stock := NULL;
        IF p_bloquear THEN
            SELECT s.stock INTO v_stock FROM pro_stock s
            WHERE s.id_producto = v_req.id AND s.id_almacen = v_almacen AND s.estado = 1
            FOR UPDATE;
        ELSE
            SELECT s.stock INTO v_stock FROM pro_stock s
            WHERE s.id_producto = v_req.id AND s.id_almacen = v_almacen AND s.estado = 1;
        END IF;
        IF COALESCE(v_stock, 0) < v_req.cantidad THEN
            RAISE EXCEPTION 'Stock insuficiente de "%" en el almacén "%": disponible % %, solicitado % % para toda la ruta.',
                v_req.nombre, v_nombre_almacen, COALESCE(v_stock, 0), v_req.unidad, v_req.cantidad, v_req.unidad;
        END IF;
    END LOOP;
END;
$function$;
