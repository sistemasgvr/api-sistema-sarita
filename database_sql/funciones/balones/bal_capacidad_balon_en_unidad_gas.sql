-- Capacidad nominal del tipo de un balón, expresada en la unidad de medida del
-- producto-gas que contiene (decisión 3 del plan).
--
-- Motivo: bal_tipo_balon puede estar catalogado en MT3 mientras su gas se vende en KG
-- (hoy: los 4 tipos de Acetileno y los 4 de Dióxido de Carbono). Antes esa cantidad
-- llegaba tal cual a pro_stock y mezclaba kilos con metros cúbicos en el mismo saldo.
--
-- Devuelve NULL si el balón no existe o no tiene capacidad de tipo; el llamador
-- decide el fallback.
DROP FUNCTION IF EXISTS bal_capacidad_balon_en_unidad_gas(integer);

CREATE OR REPLACE FUNCTION bal_capacidad_balon_en_unidad_gas(p_id_balon INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_capacidad NUMERIC;
    v_id_unidad_tipo INTEGER;
    v_id_producto_gas INTEGER;
BEGIN
    IF p_id_balon IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT tb.capacidad, tb.id_unidad_medida, COALESCE(b.id_producto_gas, tb.id_gas)
    INTO v_capacidad, v_id_unidad_tipo, v_id_producto_gas
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND OR COALESCE(v_capacidad, 0) <= 0 OR v_id_producto_gas IS NULL THEN
        RETURN v_capacidad;
    END IF;

    RETURN inv_convertir_a_unidad_producto(v_id_producto_gas, v_capacidad, v_id_unidad_tipo);
END;
$function$;
