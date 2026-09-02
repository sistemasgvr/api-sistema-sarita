-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_producto_mueve_kardex_venta
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.816Z
DROP FUNCTION IF EXISTS ven_producto_mueve_kardex_venta(p_id_producto integer, p_descripcion character varying);

CREATE OR REPLACE FUNCTION ven_producto_mueve_kardex_venta(p_id_producto integer, p_descripcion character varying DEFAULT NULL::character varying)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_afecta BOOLEAN;
    v_servicio BOOLEAN;
    v_alquilable BOOLEAN;
BEGIN
    IF p_id_producto IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT
        COALESCE(p.afecta_stock, FALSE),
        COALESCE(p.es_servicio, FALSE),
        COALESCE(p.es_alquilable, FALSE)
    INTO v_afecta, v_servicio, v_alquilable
    FROM pro_producto p
    WHERE p.id = p_id_producto;

    IF NOT FOUND OR NOT v_afecta OR v_servicio OR v_alquilable THEN
        RETURN FALSE;
    END IF;

    IF p_descripcion IS NOT NULL AND BTRIM(p_descripcion) ~* 'garant[ií]a' THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$function$
