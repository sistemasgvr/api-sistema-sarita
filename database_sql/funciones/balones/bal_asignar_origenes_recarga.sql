-- Valida disponibilidad de gas para una recarga y sugiere balón(es) de referencia.
-- Fase 1: el gas es stock de producto por almacén (pro_stock), no se rastrea m³ por
-- cilindro individual. Este check de disponibilidad ahora es real (contra pro_stock);
-- el "origen" que se registra en bal_movimiento_recarga_origen es solo una referencia
-- informativa de qué cilindro físico se usó (si se indicó uno) o el más antiguo
-- disponible del mismo gas, no un reparto exacto de m³ por cilindro (eso ya no existe).
CREATE OR REPLACE FUNCTION bal_asignar_origenes_recarga(
    p_id_producto_gas INTEGER,
    p_capacidad_requerida NUMERIC,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_balon_preferido INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_requerida NUMERIC;
    v_total_disponible NUMERIC := 0;
    v_origenes JSONB := '[]'::JSONB;
    v_id_balon_origen INTEGER;
    v_codigo_balon_origen VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object('error', 'El producto gas es obligatorio', 'origenes', '[]'::JSON);
    END IF;

    v_requerida := COALESCE(p_capacidad_requerida, 0);
    IF v_requerida <= 0 THEN
        RETURN json_build_object('error', 'La capacidad requerida debe ser mayor a cero', 'origenes', '[]'::JSON);
    END IF;

    IF p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio para validar el stock de gas', 'origenes', '[]'::JSON);
    END IF;

    v_total_disponible := inv_stock_producto(p_id_producto_gas, p_id_almacen);

    IF v_total_disponible < v_requerida THEN
        RETURN json_build_object(
            'error',
            format(
                'Stock insuficiente de gas en almacén (disponible: %s m³, requerido: %s m³)',
                TRIM(TO_CHAR(v_total_disponible, 'FM999999990.####')),
                TRIM(TO_CHAR(v_requerida, 'FM999999990.####'))
            ),
            'origenes', '[]'::JSON,
            'total_disponible', v_total_disponible,
            'requerido', v_requerida
        );
    END IF;

    -- Balón de referencia: el preferido si es válido, si no el EMPRESA/EN_ALMACEN más
    -- antiguo del mismo gas (solo para trazabilidad, no reparte m³ real por cilindro).
    IF p_id_balon_preferido IS NOT NULL THEN
        SELECT b.id, b.codigo_balon INTO v_id_balon_origen, v_codigo_balon_origen
        FROM bal_balon b
        WHERE b.id = p_id_balon_preferido AND b.estado = 1;
    END IF;

    IF v_id_balon_origen IS NULL THEN
        SELECT b.id, b.codigo_balon INTO v_id_balon_origen, v_codigo_balon_origen
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
          AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
          AND b.id_producto_gas = p_id_producto_gas
          AND b.id_almacen = p_id_almacen
        ORDER BY b.fecha_creacion ASC NULLS LAST, b.id ASC
        LIMIT 1;
    END IF;

    IF v_id_balon_origen IS NOT NULL THEN
        v_origenes := jsonb_build_array(
            jsonb_build_object(
                'id_balon', v_id_balon_origen,
                'codigo_balon', v_codigo_balon_origen,
                'cantidad', v_requerida,
                'orden', 1
            )
        );
    END IF;

    RETURN json_build_object(
        'origenes', v_origenes,
        'requerido', v_requerida,
        'total_disponible', v_total_disponible,
        'id_balon_origen_principal', v_id_balon_origen,
        'etiqueta', CASE
            WHEN v_codigo_balon_origen IS NOT NULL THEN
                v_codigo_balon_origen || ' (' || TRIM(TO_CHAR(v_requerida, 'FM999999990.####')) || ' m³)'
            ELSE NULL
        END
    );
END;
$function$;
