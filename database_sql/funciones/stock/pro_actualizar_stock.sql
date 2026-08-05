CREATE OR REPLACE FUNCTION pro_actualizar_stock(
    p_id INTEGER,
    p_stock NUMERIC DEFAULT NULL,
    p_stock_minimo NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- La cantidad solo cambia por movimientos de inventario.
    IF p_stock IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'La cantidad de stock solo se modifica con movimientos (ingreso, salida o ajuste). Aquí solo puedes cambiar el stock mínimo.',
            'registro',
            NULL
        );
    END IF;

    IF p_stock_minimo IS NOT NULL AND p_stock_minimo < 0 THEN
        RETURN json_build_object('error', 'El stock mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    SELECT s.id_producto
    INTO v_id_producto
    FROM pro_stock s
    WHERE s.id = p_id AND s.estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT
        REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
        COALESCE(p.es_gas, FALSE)
    INTO v_nombre_unidad, v_es_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = v_id_producto;

    IF COALESCE(v_es_gas, FALSE) THEN
        RETURN json_build_object(
            'error',
            'El stock de gas no se ajusta aquí. Usa Balones / Stock de gas o Libro de cilindros.',
            'registro',
            NULL
        );
    END IF;

    IF NOT COALESCE(v_es_gas, FALSE)
       AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
    THEN
        IF p_stock_minimo IS NOT NULL AND p_stock_minimo <> TRUNC(p_stock_minimo) THEN
            RETURN json_build_object(
                'error',
                'El stock mínimo debe ser entero (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;
    END IF;

    UPDATE pro_stock
    SET
        stock_minimo = COALESCE(p_stock_minimo, stock_minimo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_stock(p_id);
END;
$function$;
