-- Convierte la cantidad de una línea de salida a la unidad del producto
DROP FUNCTION IF EXISTS public.doc_cantidad_linea_en_unidad_producto (p_id_detalle integer);

CREATE OR REPLACE FUNCTION public.doc_cantidad_linea_en_unidad_producto (p_id_detalle integer) RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_id_producto INTEGER;
    v_cantidad NUMERIC;
    v_id_unidad_origen INTEGER;
BEGIN
    IF p_id_detalle IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT
        dd.id_producto,
        dd.cantidad,
        CASE
            WHEN dd.id_balon IS NOT NULL
                THEN COALESCE(dd.id_unidad_medida, tb.id_unidad_medida, p.id_unidad_medida)
            ELSE COALESCE(dd.id_unidad_medida, p.id_unidad_medida)
        END
    INTO v_id_producto, v_cantidad, v_id_unidad_origen
    FROM doc_salida_detalle dd
    LEFT JOIN pro_producto p ON p.id = dd.id_producto
    LEFT JOIN bal_balon b ON b.id = dd.id_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE dd.id = p_id_detalle;

    IF NOT FOUND OR v_id_producto IS NULL THEN
        RETURN v_cantidad;
    END IF;

    RETURN inv_convertir_a_unidad_producto(v_id_producto, v_cantidad, v_id_unidad_origen);
END;
$function$;
