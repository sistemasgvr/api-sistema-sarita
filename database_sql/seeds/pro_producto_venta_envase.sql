-- Producto interno del POS para cobrar el cilindro separado del gas.
-- No afecta pro_stock: el cilindro se controla mediante bal_balon.
-- El precio se ingresa en cada venta. No usar un ID fijo entre entornos.
-- Puede ejecutarse varias veces sin duplicar el producto.
DO $seed$
DECLARE
    v_id INTEGER;
    v_id_unidad INTEGER;
BEGIN
    SELECT id INTO v_id
    FROM pro_producto
    WHERE UPPER(BTRIM(codigo)) = 'VTA-ENVASE'
    ORDER BY id
    LIMIT 1;

    IF v_id IS NOT NULL THEN
        -- Recuperar un producto inactivo conservando su ID y sus comprobantes.
        UPDATE pro_producto
        SET estado = 1, fecha_modificacion = NOW()
        WHERE id = v_id AND estado <> 1;
        RETURN;
    END IF;

    SELECT o.id INTO v_id_unidad
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE l.nombre = 'UnidadMedida'
      AND o.nombre = 'UNID'
      AND o.estado = 1
    ORDER BY o.id
    LIMIT 1;

    INSERT INTO pro_producto (
        codigo, nombre, id_unidad_medida,
        es_gas, es_servicio, es_alquilable, es_mantenimiento,
        afecta_stock, precio, precio_compra, precio_garantia, estado
    ) VALUES (
        'VTA-ENVASE', 'Venta de envase', v_id_unidad,
        FALSE, FALSE, FALSE, FALSE,
        FALSE, 0, 0, 0, 1
    );
END;
$seed$;
