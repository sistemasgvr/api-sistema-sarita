-- Escenarios de edición del catálogo que rompían el stock de gas (decisión 3, ampliada).
--
-- 1. pro_crear_producto / pro_actualizar_producto forzaban afecta_stock = FALSE cuando
--    es_gas = TRUE. Es lógica pre-Fase 1 (cuando el gas se controlaba por cilindro).
--    Con ella, editar CUALQUIER campo de un gas apagaba su control de stock en silencio:
--    inv_registrar_movimiento deja de tocar pro_stock si afecta_stock es FALSE.
--    Corregido en los cuerpos de función (database_sql/funciones/productos/).
--
-- 2. Cambiar pro_producto.id_unidad_medida reinterpretaba el saldo: pro_stock no guarda
--    unidad propia, se lee siempre en la unidad ACTUAL del producto. Ahora se bloquea
--    si hay stock o movimientos, salvo que se confirme con p_convertir_stock, en cuyo
--    caso el saldo se convierte mediante un movimiento de AJUSTE (kardex trazable).
--
-- 3. Un gas con tipos de balón en otra unidad ya no puede quedarse sin factor de
--    conversión: se revalida al guardar el producto.
--
-- Los cuerpos de función se aplican desde database_sql/funciones/ con:
--     node database_sql/scripts/rebuild-schema-from-repo.js --functions

BEGIN;

-- Reparar gases a los que la lógica anterior ya les apagó el stock.
UPDATE pro_producto
SET afecta_stock = TRUE,
    fecha_modificacion = NOW()
WHERE es_gas = TRUE
  AND COALESCE(es_servicio, FALSE) = FALSE
  AND COALESCE(afecta_stock, FALSE) = FALSE;

COMMIT;
