-- =============================================================================
-- 06 PROPANO COMO PRODUCTO (no gas con cilindro en POS)
-- Tras 05: quita es_gas para que aparezcan en Producto o accesorio.
-- Stock sigue en pro_stock (afecta_stock = TRUE).
-- =============================================================================
BEGIN;
SET TIME ZONE 'America/Lima';

UPDATE pro_producto
SET es_gas = FALSE,
    afecta_stock = TRUE,
    id_usuario_modificacion = 1,
    fecha_modificacion = NOW()
WHERE codigo IN ('GAS-PROPANO-10', 'GAS-PROPANO-45', 'GAS-PROPANO');

COMMIT;
