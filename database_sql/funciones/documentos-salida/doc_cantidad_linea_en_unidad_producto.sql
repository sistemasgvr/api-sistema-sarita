-- Function: doc_cantidad_linea_en_unidad_producto
-- Creada: 2026-09-10 (migración 20260910_doc_generar_um_conversion).
--
-- Cantidad de una línea de doc_salida_detalle expresada en la U.M. del
-- producto, que es la unidad en la que vive pro_stock.
--
-- Existe para que la SALIDA y el RETORNO de la misma orden usen exactamente la
-- misma regla. Antes doc_generar_salida registraba la cantidad cruda mientras
-- bal_sincronizar_gas_retorno_planta convertía, así que cuando la U.M. de la
-- línea no era la del producto (caso típico: capacidades en KG contra un gas
-- en MT3) el neto de stock quedaba sesgado.
--
-- Unidad de origen, por orden de preferencia:
--   1) la U.M. persistida en la línea (doc_crear_salida_detalle ya la
--      completa con la del producto cuando no viene);
--   2) en líneas de cilindro, la U.M. de la capacidad del tipo de balón: esa
--      es la unidad en la que se declaran las capacidades;
--   3) la U.M. del propio producto, que hace la conversión neutra.
--
-- Las líneas de envase puro (sin producto) devuelven la cantidad tal cual: ahí
-- la cantidad cuenta cilindros, no gas.
--
-- Puede lanzar excepción (falta factor_kg_m3 / unidad no convertible) porque
-- inv_convertir_a_unidad_producto lo hace. Los callers que mueven inventario
-- deben probarla en seco antes de empezar.
DROP FUNCTION IF EXISTS doc_cantidad_linea_en_unidad_producto(p_id_detalle integer);

CREATE OR REPLACE FUNCTION doc_cantidad_linea_en_unidad_producto(p_id_detalle integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
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
