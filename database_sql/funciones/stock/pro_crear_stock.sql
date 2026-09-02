-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_crear_stock
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.775Z
DROP FUNCTION IF EXISTS pro_crear_stock(p_id_almacen integer, p_id_producto integer, p_stock numeric, p_stock_minimo numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_crear_stock(p_id_almacen integer, p_id_producto integer, p_stock numeric DEFAULT 0, p_stock_minimo numeric DEFAULT 0, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_inactivo INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
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

    SELECT
        REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
        COALESCE(p.es_gas, FALSE)
    INTO v_nombre_unidad, v_es_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = p_id_producto;

    -- Gases (m³) pueden ser decimales aunque la U.M. esté mal catalogada como UNID.
    IF NOT COALESCE(v_es_gas, FALSE)
       AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
    THEN
        IF COALESCE(p_stock, 0) <> TRUNC(COALESCE(p_stock, 0)) THEN
            RETURN json_build_object(
                'error',
                'El stock debe ser entero (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;
        IF COALESCE(p_stock_minimo, 0) <> TRUNC(COALESCE(p_stock_minimo, 0)) THEN
            RETURN json_build_object(
                'error',
                'El stock mínimo debe ser entero (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;
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
$function$
