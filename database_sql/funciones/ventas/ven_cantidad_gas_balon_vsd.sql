-- Calcula la cantidad de gas de la línea de un balón en una venta sin documento (VSD)
DROP FUNCTION IF EXISTS public.ven_cantidad_gas_balon_vsd (p_id integer, p_balon integer, p_original integer);

CREATE OR REPLACE FUNCTION public.ven_cantidad_gas_balon_vsd (
  p_id integer,
  p_balon integer,
  p_original integer DEFAULT NULL::integer
) RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE v_original integer := p_original; v_producto integer; v_capacidad numeric; v_qty numeric; v_count integer;
BEGIN
    SELECT id_producto_gas,bal_capacidad_balon_en_unidad_gas(id) INTO v_producto,v_capacidad FROM bal_balon WHERE id=p_balon AND estado=1;
    IF v_original IS NULL THEN
        SELECT (datos->>'idBalonOriginal')::integer INTO v_original FROM ven_vsd_operacion
            WHERE id_comprobante=p_id AND tipo='CAMBIO_BALON' AND (datos->>'idBalonNuevo')::integer=p_balon ORDER BY id DESC LIMIT 1;
    END IF;
    v_original := COALESCE(v_original,p_balon);
    SELECT sum(cantidad) INTO v_qty FROM ven_comprobante_detalle
        WHERE id_comprobante=p_id AND estado=1 AND id_producto=v_producto AND id_balon IN (p_balon,v_original);
    IF v_qty IS NULL THEN
        SELECT count(*),max(cantidad) INTO v_count,v_qty FROM ven_comprobante_detalle
            WHERE id_comprobante=p_id AND estado=1 AND id_producto=v_producto;
        IF v_count <> 1 THEN RETURN NULL; END IF;
    END IF;
    IF COALESCE(v_capacidad,0)<=0 OR COALESCE(v_qty,0)<=0 OR v_qty>v_capacidad THEN RETURN NULL; END IF;
    RETURN v_qty;
END;
$function$;
