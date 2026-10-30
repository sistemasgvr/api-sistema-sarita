-- Límite nominal del cilindro, independiente de las libras manuales.
CREATE OR REPLACE FUNCTION public.bal_validar_capacidad_salida_ruta(p_id_balon integer, p_m3_salida numeric)
RETURNS void LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_d RECORD;
    v_capacidad_m3 NUMERIC;
BEGIN
    SELECT b.codigo_balon, tb.nombre AS tipo, tb.capacidad, tb.id_unidad_medida,
           UPPER(TRIM(um.nombre)) AS unidad, COALESCE(b.id_producto_gas, tb.id_gas) AS id_gas
    INTO v_d
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
    LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
    WHERE b.id = p_id_balon AND b.estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El cilindro % no existe o está inactivo', p_id_balon; END IF;
    IF COALESCE(v_d.capacidad, 0) <= 0 OR v_d.capacidad::TEXT IN ('NaN', 'Infinity', '-Infinity')
       OR COALESCE(v_d.unidad, '') NOT IN ('MT3', 'M3', 'M³', 'KG', 'KGM', 'LB') THEN
        RAISE EXCEPTION 'Cilindro %: configura la capacidad nominal y su unidad en el tipo "%" para validar los m³ de salida.',
            v_d.codigo_balon, COALESCE(v_d.tipo, '(sin tipo)');
    END IF;
    IF v_d.unidad IN ('MT3', 'M3', 'M³') THEN
        v_capacidad_m3 := v_d.capacidad;
    ELSE
        BEGIN
            v_capacidad_m3 := inv_convertir_a_unidad_producto(v_d.id_gas, v_d.capacidad, v_d.id_unidad_medida);
        EXCEPTION WHEN raise_exception THEN
            RAISE EXCEPTION 'Cilindro %: no se puede verificar la capacidad del tipo "%" en m³. Revisa la equivalencia del producto gas. %',
                v_d.codigo_balon, v_d.tipo, SQLERRM;
        END;
    END IF;
    IF p_m3_salida > v_capacidad_m3 THEN
        RAISE EXCEPTION 'Cilindro %: salida solicitada % m³; la capacidad máxima del tipo "%" es % m³.',
            v_d.codigo_balon, p_m3_salida, v_d.tipo, v_capacidad_m3;
    END IF;
END;
$function$;
