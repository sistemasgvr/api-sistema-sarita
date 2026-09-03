-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_sucursal_de_cuenta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.960Z
DROP FUNCTION IF EXISTS fin_sucursal_de_cuenta(p_id_cuenta integer);

CREATE OR REPLACE FUNCTION fin_sucursal_de_cuenta(p_id_cuenta integer)
 RETURNS integer
 LANGUAGE sql
 STABLE
AS $function$
    SELECT COALESCE(
        vc.id_sucursal,
        vc_padre.id_sucursal,
        cc.id_sucursal,
        cc_padre.id_sucursal
    )
    FROM fin_cuenta fc
    LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
    LEFT JOIN fin_cuenta fp ON fp.id = fc.id_cuenta_padre
    LEFT JOIN ven_comprobante vc_padre ON vc_padre.id = fp.id_comprobante_venta
    LEFT JOIN com_comprobante_compra cc ON cc.id = fc.id_comprobante_compra
    LEFT JOIN com_comprobante_compra cc_padre ON cc_padre.id = fp.id_comprobante_compra
    WHERE fc.id = p_id_cuenta;
$function$;
