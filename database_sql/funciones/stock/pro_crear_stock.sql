CREATE OR REPLACE FUNCTION pro_crear_stock(
    p_id_almacen INTEGER,
    p_id_producto INTEGER,
    p_stock NUMERIC DEFAULT 0,
    p_stock_minimo NUMERIC DEFAULT 0,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_inactivo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_stock
        WHERE id_almacen = p_id_almacen
          AND id_producto = p_id_producto
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe un registro de stock activo para este producto en el almacén',
            'registro',
            NULL
        );
    END IF;

    IF COALESCE(p_stock, 0) < 0 OR COALESCE(p_stock_minimo, 0) < 0 THEN
        RETURN json_build_object('error', 'El stock y el stock mínimo no pueden ser negativos', 'registro', NULL);
    END IF;

    -- Si hubo baja lógica previa, UNIQUE(id_almacen, id_producto) bloquea el INSERT:
    -- reactivar y actualizar cantidades.
    SELECT id
    INTO v_id_inactivo
    FROM pro_stock
    WHERE id_almacen = p_id_almacen
      AND id_producto = p_id_producto
      AND estado = 0
    LIMIT 1;

    IF v_id_inactivo IS NOT NULL THEN
        UPDATE pro_stock
        SET
            stock = COALESCE(p_stock, 0),
            stock_minimo = COALESCE(p_stock_minimo, 0),
            estado = 1,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_inactivo;

        RETURN pro_obtener_stock(v_id_inactivo);
    END IF;

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
        COALESCE(p_stock, 0),
        COALESCE(p_stock_minimo, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_stock(v_id);
END;
$function$;
