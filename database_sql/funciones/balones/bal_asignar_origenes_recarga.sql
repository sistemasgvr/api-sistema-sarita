-- Asigna balones EMPRESA LLENOS (FIFO) para cubrir una capacidad.
-- Si el primero solo tiene 2 m³ y se piden 5, toma 2 + el resto del siguiente.
CREATE OR REPLACE FUNCTION bal_asignar_origenes_recarga(
    p_id_producto_gas INTEGER,
    p_capacidad_requerida NUMERIC,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_balon_preferido INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
VOLATILE
AS $function$
DECLARE
    v_requerida NUMERIC;
    v_faltante NUMERIC;
    v_origenes JSONB := '[]'::JSONB;
    v_total_disponible NUMERIC := 0;
    r RECORD;
    v_tomar NUMERIC;
    v_orden INT := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object('error', 'El producto gas es obligatorio', 'origenes', '[]'::JSON);
    END IF;

    v_requerida := COALESCE(p_capacidad_requerida, 0);
    IF v_requerida <= 0 THEN
        RETURN json_build_object('error', 'La capacidad requerida debe ser mayor a cero', 'origenes', '[]'::JSON);
    END IF;

    SELECT COALESCE(SUM(bal_capacidad_disponible_balon(b.id)), 0)
    INTO v_total_disponible
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
    WHERE b.estado = 1
      AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
      AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
      AND COALESCE(ec.nombre, '') = 'LLENO'
      AND b.id_producto_gas = p_id_producto_gas
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND bal_capacidad_disponible_balon(b.id) > 0;

    IF v_total_disponible < v_requerida THEN
        RETURN json_build_object(
            'error',
            format(
                'Stock insuficiente de gas en balones empresa (disponible: %s m³, requerido: %s m³)',
                TRIM(TO_CHAR(v_total_disponible, 'FM999999990.####')),
                TRIM(TO_CHAR(v_requerida, 'FM999999990.####'))
            ),
            'origenes', '[]'::JSON,
            'total_disponible', v_total_disponible,
            'requerido', v_requerida
        );
    END IF;

    v_faltante := v_requerida;

    FOR r IN
        WITH base AS (
            SELECT
                b.id,
                b.codigo_balon,
                bal_capacidad_disponible_balon(b.id) AS capacidad_disponible,
                tb.capacidad AS capacidad_tipo,
                a.nombre AS nombre_almacen,
                b.fecha_creacion,
                CASE
                    WHEN p_id_balon_preferido IS NOT NULL AND b.id = p_id_balon_preferido THEN 0
                    ELSE 1
                END AS prioridad
            FROM bal_balon b
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_almacen a ON a.id = b.id_almacen
            LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
            WHERE b.estado = 1
              AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
              AND COALESCE(eb.nombre, '') = 'EN_ALMACEN'
              AND COALESCE(ec.nombre, '') = 'LLENO'
              AND b.id_producto_gas = p_id_producto_gas
              AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
              AND bal_capacidad_disponible_balon(b.id) > 0
        )
        SELECT *
        FROM base
        ORDER BY prioridad ASC, fecha_creacion ASC NULLS LAST, id ASC
    LOOP
        EXIT WHEN v_faltante <= 0;

        v_tomar := LEAST(r.capacidad_disponible, v_faltante);
        IF v_tomar <= 0 THEN
            CONTINUE;
        END IF;

        v_orden := v_orden + 1;
        v_origenes := v_origenes || jsonb_build_array(
            jsonb_build_object(
                'id_balon', r.id,
                'codigo_balon', r.codigo_balon,
                'cantidad', v_tomar,
                'capacidad_disponible', r.capacidad_disponible,
                'capacidad_tipo', r.capacidad_tipo,
                'nombre_almacen', r.nombre_almacen,
                'orden', v_orden
            )
        );
        v_faltante := v_faltante - v_tomar;
    END LOOP;

    IF v_faltante > 0 THEN
        RETURN json_build_object(
            'error',
            format(
                'No se pudo completar la asignación (faltan %s m³)',
                TRIM(TO_CHAR(v_faltante, 'FM999999990.####'))
            ),
            'origenes', '[]'::JSON
        );
    END IF;

    RETURN json_build_object(
        'origenes', v_origenes,
        'requerido', v_requerida,
        'id_balon_origen_principal', (v_origenes->0->>'id_balon')::INTEGER,
        'etiqueta', (
            SELECT string_agg(
                (o->>'codigo_balon') || ' (' || TRIM(TO_CHAR((o->>'cantidad')::NUMERIC, 'FM999999990.####')) || ' m³)',
                ' + '
                ORDER BY (o->>'orden')::INT
            )
            FROM jsonb_array_elements(v_origenes) o
        )
    );
END;
$function$;
