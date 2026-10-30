-- Conversión estricta para rutas: capacidad nominal en su unidad a m³/lb de gas.
CREATE OR REPLACE FUNCTION public.bal_factor_ruta_balon(p_id_balon integer, p_validar boolean DEFAULT true)
RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_d RECORD;
    v_cap_m3 NUMERIC;
BEGIN
    SELECT b.codigo_balon, tb.nombre AS tipo, tb.capacidad, tb.capacidad_lb,
           UPPER(TRIM(um.nombre)) AS unidad, p.factor_kg_m3, p.factor_lb_m3
    INTO v_d
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
    LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
    LEFT JOIN pro_producto p ON p.id = COALESCE(b.id_producto_gas, tb.id_gas) AND p.estado = 1
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cilindro % no existe o está inactivo', p_id_balon;
    END IF;
    IF COALESCE(v_d.capacidad, 0) <= 0 OR COALESCE(v_d.capacidad_lb, 0) <= 0 THEN
        RAISE EXCEPTION 'Cilindro %: configura la capacidad nominal, su unidad y las libras de gas lleno en el tipo "%".',
            v_d.codigo_balon, COALESCE(v_d.tipo, '(sin tipo)');
    END IF;

    IF v_d.unidad IN ('MT3', 'M3', 'M³') THEN
        v_cap_m3 := v_d.capacidad;
    ELSIF v_d.unidad IN ('KG', 'KGM') THEN
        IF COALESCE(v_d.factor_kg_m3, 0) <= 0 THEN
            RAISE EXCEPTION 'Cilindro %: configura el factor de kg a m³ del producto gas para convertir la capacidad de su tipo (% kg).',
                v_d.codigo_balon, v_d.capacidad;
        END IF;
        v_cap_m3 := v_d.capacidad * v_d.factor_kg_m3;
    ELSIF v_d.unidad = 'LB' THEN
        IF COALESCE(v_d.factor_lb_m3, 0) <= 0 THEN
            RAISE EXCEPTION 'Cilindro %: configura el factor de lb a m³ del producto gas.', v_d.codigo_balon;
        END IF;
        v_cap_m3 := v_d.capacidad * v_d.factor_lb_m3;
    ELSE
        RAISE EXCEPTION 'Cilindro %: la unidad "%" del tipo "%" no permite calcular m³. Configura m³, kg o lb y su equivalencia.',
            v_d.codigo_balon, COALESCE(v_d.unidad, '(sin unidad)'), v_d.tipo;
    END IF;
    RETURN v_cap_m3 / v_d.capacidad_lb;
EXCEPTION WHEN raise_exception THEN
    IF p_validar THEN RAISE; END IF;
    RETURN NULL;
END;
$function$;
