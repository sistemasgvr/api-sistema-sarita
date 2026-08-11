CREATE OR REPLACE FUNCTION bal_registrar_retorno_ruta_pueblo(
    p_id INTEGER,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_almacen INTEGER;
    v_factor NUMERIC;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_lb_retorno NUMERIC;
    v_id_det INTEGER;
    v_lb_salida NUMERIC;
    v_m3_delta NUMERIC;
    v_restante_m3 NUMERIC;
    v_mov JSON;
    v_contenido VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen, r.factor_lb_m3
    INTO v_estado, v_id_almacen, v_factor
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado NOT IN ('EN_RUTA', 'ABIERTA') THEN
        RETURN json_build_object('error', 'Solo se registra retorno en rutas ABIERTA o EN_RUTA', 'registro', NULL);
    END IF;

    -- Si aún ABIERTA, iniciar primero (salida física)
    IF v_estado = 'ABIERTA' THEN
        PERFORM bal_iniciar_ruta_pueblo(p_id, p_id_usuario_auditoria);
        SELECT er.nombre, r.id_almacen, r.factor_lb_m3
        INTO v_estado, v_id_almacen, v_factor
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id = p_id AND r.estado = 1;
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe indicar libras de retorno por cilindro', 'registro', NULL);
    END IF;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_balon := COALESCE(
            (v_detalle->>'idBalon')::INTEGER,
            (v_detalle->>'id_balon')::INTEGER
        );
        v_lb_retorno := COALESCE(
            (v_detalle->>'lbRetorno')::NUMERIC,
            (v_detalle->>'lb_retorno')::NUMERIC
        );

        IF v_id_balon IS NULL OR v_lb_retorno IS NULL OR v_lb_retorno < 0 THEN
            RAISE EXCEPTION 'Cada ítem requiere idBalon y lbRetorno ≥ 0';
        END IF;

        SELECT d.id, d.lb_salida
        INTO v_id_det, v_lb_salida
        FROM bal_ruta_pueblo_detalle d
        WHERE d.id_ruta_pueblo = p_id
          AND d.id_balon = v_id_balon
          AND d.estado = 1;

        IF v_id_det IS NULL THEN
            RAISE EXCEPTION 'Cilindro % no pertenece a esta ruta', v_id_balon;
        END IF;

        IF v_lb_retorno > v_lb_salida THEN
            RAISE EXCEPTION 'Cilindro %: lb retorno (%.4f) no puede superar lb salida (%.4f)',
                v_id_balon, v_lb_retorno, v_lb_salida;
        END IF;

        v_m3_delta := ROUND((v_lb_salida - v_lb_retorno) * v_factor, 4);
        v_restante_m3 := ROUND(v_lb_retorno * v_factor, 4);
        v_contenido := CASE
            WHEN v_lb_retorno <= 0 THEN 'VACIO'
            ELSE 'LLENO'
        END;

        UPDATE bal_ruta_pueblo_detalle
        SET
            lb_retorno = v_lb_retorno,
            m3_delta = v_m3_delta,
            capacidad_restante_m3 = v_restante_m3,
            observacion = COALESCE(
                NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                observacion
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_det;

        -- Retorno a almacén con residual (CY4: no forzar vacío)
        v_mov := bal_registrar_salida_documento(
            v_id_balon,
            'RETORNO_LIMA',
            p_id,
            'RUTA_PUEBLO',
            NULL,
            NULL,
            'EN_ALMACEN',
            FALSE,
            v_id_almacen,
            format('Retorno ruta pueblos #%s · %.4f lb residual', p_id, v_lb_retorno),
            p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            -- Si ya existe movimiento retorno idempotente, igual actualizamos balón
            NULL;
        END IF;

        UPDATE bal_balon
        SET
            id_almacen = v_id_almacen,
            id_cliente_ubicacion = NULL,
            id_estado_balon = (
                SELECT lo.id
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
                LIMIT 1
            ),
            capacidad_restante = CASE WHEN v_restante_m3 > 0 THEN v_restante_m3 ELSE 0 END,
            id_estado_contenido = COALESCE(bal_id_estado_contenido(v_contenido), id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon AND estado = 1;
    END LOOP;

    UPDATE bal_ruta_pueblo
    SET
        m3_calculado = (
            SELECT COALESCE(SUM(d.m3_delta), 0)
            FROM bal_ruta_pueblo_detalle d
            WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;
