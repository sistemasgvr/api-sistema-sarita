CREATE OR REPLACE FUNCTION pro_crear_movimiento(
    p_fecha DATE,
    p_id_producto INTEGER,
    p_id_almacen INTEGER,
    p_id_tipo_movimiento INTEGER,
    p_cantidad NUMERIC,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_stock INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_cantidad NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
    v_es_salida BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del movimiento es obligatoria', 'registro', NULL);
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_movimiento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de movimiento indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT afecta_stock INTO v_afecta_stock
    FROM pro_producto
    WHERE id = p_id_producto;

    SELECT nombre INTO v_nombre_tipo_movimiento
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_movimiento;

    v_cantidad := ABS(p_cantidad);
    v_es_salida := v_nombre_tipo_movimiento ILIKE '%SALIDA%';

    v_stock_anterior := 0;
    v_stock_nuevo := 0;

    IF v_afecta_stock THEN
        SELECT id, stock INTO v_id_stock, v_stock_anterior
        FROM pro_stock
        WHERE id_almacen = p_id_almacen
          AND id_producto = p_id_producto
          AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            INSERT INTO pro_stock (
                id_almacen,
                id_producto,
                stock,
                stock_minimo,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                p_id_almacen,
                p_id_producto,
                0,
                0,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            )
            RETURNING id, stock INTO v_id_stock, v_stock_anterior;
        END IF;

        IF v_es_salida THEN
            v_stock_nuevo := v_stock_anterior - v_cantidad;
        ELSE
            v_stock_nuevo := v_stock_anterior + v_cantidad;
        END IF;

        IF v_stock_nuevo < 0 THEN
            RETURN json_build_object('error', 'Stock insuficiente para registrar la salida', 'registro', NULL);
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_stock;
    END IF;

    INSERT INTO pro_movimientos (
        fecha,
        id_producto,
        id_almacen,
        id_tipo_movimiento,
        cantidad,
        stock_anterior,
        stock_nuevo,
        id_documento_ref,
        id_tipo_documento_ref,
        glosa,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_fecha,
        p_id_producto,
        p_id_almacen,
        p_id_tipo_movimiento,
        v_cantidad,
        CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
        CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
        p_id_documento_ref,
        p_id_tipo_documento_ref,
        p_glosa,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_movimiento(v_id);
END;
$function$;
