-- =============================================================================
-- 03 PLANTAS: upgrade Cliente -> Cliente/Proveedor o alta nueva
-- =============================================================================
-- No hay cambios: todas las plantas del Excel ya existen como Proveedor
-- o Cliente/Proveedor. Detalle:
--   doc 20536698834 | <openpyxl.worksheet.formula.ArrayFormula object at 0x000001CFEF5010D0> | id_tipo_cliente=3 | action=keep
--   doc 20607948675 | <openpyxl.worksheet.formula.ArrayFormula object at 0x000001CFEF502450> | id_tipo_cliente=3 | action=keep
BEGIN;
-- (noop)
COMMIT;