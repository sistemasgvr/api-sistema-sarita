CREATE OR REPLACE FUNCTION bal_crear_ruta_pueblo(
    p_fecha DATE DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_id_chofer INTEGER DEFAULT NULL,
    p_factor_lb_m3 NUMERIC DEFAULT NULL,
    p_tolerancia_m3 NUMERIC DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_lb_salida NUMERIC;
    v_sellado BOOLEAN;
    v_item INTEGER := 0;
    v_balones INTEGER[] := ARRAY[]::INTEGER[];
    v_estado_balon VARCHAR;
    v_id_almacen_balon INTEGER;
    v_factor NUMERIC;
    v_tolerancia NUMERIC;
    v_cap_m3 NUMERIC;
    v_cap_lb NUMERIC;
    v_factor_tipo NUMERIC;
    v_factores NUMERIC[] := ARRAY[]::NUMERIC[];
    v_nombre_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1) THEN
        RETURN json_build_object('error', 'Almacén inválido', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un cilindro con libras de salida', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'ABIERTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Estado ABIERTA no configurado', 'registro', NULL);
    END IF;

    -- Tolerancia: parámetro opcional o default de empresa
    SELECT COALESCE(
        NULLIF(p_tolerancia_m3, 0),
        e.tolerancia_m3_ruta_pueblo,
        0.5000
    )
    INTO v_tolerancia
    FROM gen_empresa e
    WHERE e.estado = 1
    ORDER BY e.id
    LIMIT 1;

    IF v_tolerancia IS NULL THEN
        v_tolerancia := COALESCE(NULLIF(p_tolerancia_m3, 0), 0.5000);
    END IF;

    -- Validar cilindros y derivar factor por tipo (capacidad m³ / capacidad lb)
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;
        v_id_balon := COALESCE(
            (v_detalle->>'idBalon')::INTEGER,
            (v_detalle->>'id_balon')::INTEGER
        );
        v_lb_salida := COALESCE(
            (v_detalle->>'lbSalida')::NUMERIC,
            (v_detalle->>'lb_salida')::NUMERIC
        );

        IF v_id_balon IS NULL THEN
            RAISE EXCEPTION 'Ítem %: cilindro obligatorio', v_item;
        END IF;

        IF v_lb_salida IS NULL OR v_lb_salida < 0 THEN
            RAISE EXCEPTION 'Ítem %: libras de salida inválidas', v_item;
        END IF;

        IF v_id_balon = ANY (v_balones) THEN
            RAISE EXCEPTION 'El cilindro % está duplicado en la ruta', v_id_balon;
        END IF;
        v_balones := array_append(v_balones, v_id_balon);

        SELECT eb.nombre, b.id_almacen, tb.capacidad, tb.capacidad_lb, tb.nombre
        INTO v_estado_balon, v_id_almacen_balon, v_cap_m3, v_cap_lb, v_nombre_tipo
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
        WHERE b.id = v_id_balon AND b.estado = 1;

        IF v_estado_balon IS NULL THEN
            RAISE EXCEPTION 'Cilindro % no existe o está inactivo', v_id_balon;
        END IF;

        IF v_estado_balon NOT IN ('EN_ALMACEN') THEN
            RAISE EXCEPTION 'Cilindro % debe estar en almacén (estado actual: %)', v_id_balon, v_estado_balon;
        END IF;

        IF v_id_almacen_balon IS DISTINCT FROM p_id_almacen THEN
            RAISE EXCEPTION 'Cilindro % no está en el almacén de la ruta', v_id_balon;
        END IF;

        IF v_cap_m3 IS NULL OR v_cap_m3 <= 0 OR v_cap_lb IS NULL OR v_cap_lb <= 0 THEN
            RAISE EXCEPTION
                'El tipo "%" del cilindro % no tiene capacidad m³ y lb configuradas. Edítalo en Tipos de balón.',
                COALESCE(v_nombre_tipo, '(sin tipo)'),
                v_id_balon;
        END IF;

        v_factor_tipo := ROUND(v_cap_m3 / v_cap_lb, 6);
        v_factores := array_append(v_factores, v_factor_tipo);

        IF EXISTS (
            SELECT 1
            FROM bal_ruta_pueblo_detalle d
            INNER JOIN bal_ruta_pueblo r ON r.id = d.id_ruta_pueblo AND r.estado = 1
            INNER JOIN gen_lista_opciones er ON er.id = r.id_estado
            WHERE d.id_balon = v_id_balon
              AND d.estado = 1
              AND er.nombre IN ('ABIERTA', 'EN_RUTA')
        ) THEN
            RAISE EXCEPTION 'Cilindro % ya está en otra ruta abierta/en tránsito', v_id_balon;
        END IF;
    END LOOP;

    -- Snapshot del factor: parámetro explícito o promedio de tipos de la ruta
    IF NULLIF(p_factor_lb_m3, 0) IS NOT NULL THEN
        v_factor := p_factor_lb_m3;
    ELSE
        SELECT ROUND(AVG(f), 6) INTO v_factor
        FROM unnest(v_factores) AS f;
    END IF;

    INSERT INTO bal_ruta_pueblo (
        fecha, id_almacen, id_usuario_responsable, id_chofer,
        factor_lb_m3, tolerancia_m3, id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        COALESCE(p_fecha, CURRENT_DATE),
        p_id_almacen,
        p_id_usuario_responsable,
        p_id_chofer,
        v_factor,
        v_tolerancia,
        v_id_estado,
        NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_balon := COALESCE(
            (v_detalle->>'idBalon')::INTEGER,
            (v_detalle->>'id_balon')::INTEGER
        );
        v_lb_salida := COALESCE(
            (v_detalle->>'lbSalida')::NUMERIC,
            (v_detalle->>'lb_salida')::NUMERIC
        );
        v_sellado := COALESCE(
            (v_detalle->>'sellado')::BOOLEAN,
            FALSE
        );

        INSERT INTO bal_ruta_pueblo_detalle (
            id_ruta_pueblo, id_balon, sellado, lb_salida, observacion,
            id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id,
            v_id_balon,
            v_sellado,
            v_lb_salida,
            NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    RETURN bal_obtener_ruta_pueblo(v_id);
END;
$function$;
