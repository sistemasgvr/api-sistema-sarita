-- =============================================================================
-- 05 STOCK INICIAL PROPANO (producto de stock, no cilindro)
-- Confirmado operativo: 08 x 10 kg + 06 x 45 kg
-- Venta: POS -> Producto o accesorio (es_gas = FALSE, afecta_stock = TRUE)
-- =============================================================================
BEGIN;
SET TIME ZONE 'America/Lima';

-- Productos SKU (producto normal + stock)
INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-PROPANO-10', 'Gas Propano 10 kg', FALSE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM pro_producto WHERE codigo = 'GAS-PROPANO-10');

INSERT INTO pro_producto (codigo, nombre, es_gas, afecta_stock, precio, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT 'GAS-PROPANO-45', 'Gas Propano 45 kg', FALSE, TRUE, 0, 1, 1, 1
WHERE NOT EXISTS (SELECT 1 FROM pro_producto WHERE codigo = 'GAS-PROPANO-45');

-- Asegurar flags por si ya existian
UPDATE pro_producto
SET es_gas = FALSE,
    afecta_stock = TRUE,
    id_usuario_modificacion = 1,
    fecha_modificacion = NOW()
WHERE codigo IN ('GAS-PROPANO-10', 'GAS-PROPANO-45', 'GAS-PROPANO');

-- Stock 10 kg = 8 unidades
INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT a.id, p.id, 8, 0, 1, 1, 1
FROM gen_almacen a
CROSS JOIN pro_producto p
WHERE UPPER(TRIM(a.nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL'))
  AND a.estado = 1
  AND p.codigo = 'GAS-PROPANO-10'
ON CONFLICT (id_almacen, id_producto) DO UPDATE
SET stock = EXCLUDED.stock,
    id_usuario_modificacion = 1,
    fecha_modificacion = NOW();

-- Stock 45 kg = 6 unidades
INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, estado, id_usuario_creacion, id_usuario_modificacion)
SELECT a.id, p.id, 6, 0, 1, 1, 1
FROM gen_almacen a
CROSS JOIN pro_producto p
WHERE UPPER(TRIM(a.nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL'))
  AND a.estado = 1
  AND p.codigo = 'GAS-PROPANO-45'
ON CONFLICT (id_almacen, id_producto) DO UPDATE
SET stock = EXCLUDED.stock,
    id_usuario_modificacion = 1,
    fecha_modificacion = NOW();

COMMIT;
