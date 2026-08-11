-- Sincroniza residual dual (m³ + lb), presión opcional y estado de contenido.
-- p_modo: SET | CLEAR | FROM_M3 | FROM_LB | FROM_PSI | FROM_BRUTO_LB
CREATE OR REPLACE FUNCTION bal_sync_capacidad_restante(
    p_id_balon INTEGER,
    p_capacidad_m3 NUMERIC DEFAULT NULL,
    p_capacidad_lb NUMERIC DEFAULT NULL,
    p_presion_psi NUMERIC DEFAULT NULL,
    p_modo VARCHAR DEFAULT 'SET',
    p_peso_bruto_lb NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo INTEGER;
    v_id_gas INTEGER;
    v_cap_nom NUMERIC;
    v_factor NUMERIC;
    v_m3 NUMERIC;
    v_lb NUMERIC;
    v_psi NUMERIC;
    v_tara NUMERIC;
    v_contenido VARCHAR;
    v_psi_min NUMERIC;
    v_alerta_vacio BOOLEAN := FALSE;
    v_modo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_modo := UPPER(TRIM(COALESCE(p_modo, 'SET')));

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'Balón obligatorio', 'ok', FALSE);
    END IF;

    SELECT b.id_tipo_balon, b.id_producto_gas, tb.capacidad
    INTO v_id_tipo, v_id_gas, v_cap_nom
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Balón no encontrado', 'ok', FALSE);
    END IF;

    v_factor := bal_factor_lb_m3(v_id_tipo, v_id_gas);
    v_psi_min := bal_psi_minimo_util();
    v_psi := p_presion_psi;

    IF v_modo = 'CLEAR' THEN
        UPDATE bal_balon
        SET
            capacidad_restante = NULL,
            capacidad_restante_lb = NULL,
            presion_actual = COALESCE(p_presion_psi, presion_actual),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;

        RETURN json_build_object(
            'ok', TRUE,
            'capacidad_restante', NULL,
            'capacidad_restante_lb', NULL,
            'presion_actual', v_psi,
            'alerta_vacio_psi', FALSE
        );
    END IF;

    IF v_modo = 'FROM_BRUTO_LB' THEN
        IF p_peso_bruto_lb IS NULL THEN
            RETURN json_build_object('error', 'peso_bruto_lb obligatorio', 'ok', FALSE);
        END IF;
        v_tara := bal_tara_lb_tipo(v_id_tipo);
        IF v_tara IS NULL THEN
            RETURN json_build_object(
                'error',
                'El tipo de balón no tiene tara (lb/kg) configurada',
                'ok', FALSE
            );
        END IF;
        v_lb := GREATEST(ROUND(p_peso_bruto_lb - v_tara, 4), 0);
        v_m3 := ROUND(v_lb * v_factor, 4);
    ELSIF v_modo = 'FROM_PSI' THEN
        IF p_presion_psi IS NULL THEN
            RETURN json_build_object('error', 'presion_psi obligatoria', 'ok', FALSE);
        END IF;
        v_psi := p_presion_psi;
        v_m3 := bal_m3_desde_psi(v_id_tipo, v_psi);
        IF v_m3 IS NULL THEN
            RETURN json_build_object(
                'error',
                'Configure capacidad (m³) y presión de llenado (PSI) en el tipo de balón',
                'ok', FALSE
            );
        END IF;
        IF v_factor > 0 THEN
            v_lb := ROUND(v_m3 / v_factor, 4);
        ELSE
            v_lb := 0;
        END IF;
    ELSIF v_modo = 'FROM_LB' THEN
        v_lb := GREATEST(COALESCE(p_capacidad_lb, 0), 0);
        v_m3 := ROUND(v_lb * v_factor, 4);
    ELSIF v_modo = 'FROM_M3' THEN
        v_m3 := GREATEST(COALESCE(p_capacidad_m3, 0), 0);
        IF v_factor > 0 THEN
            v_lb := ROUND(v_m3 / v_factor, 4);
        ELSE
            v_lb := COALESCE(p_capacidad_lb, 0);
        END IF;
    ELSE
        -- SET: báscula (lb) manda si viene; si no, m³; completar el faltante
        IF p_capacidad_lb IS NOT NULL THEN
            v_lb := GREATEST(p_capacidad_lb, 0);
            v_m3 := COALESCE(p_capacidad_m3, ROUND(v_lb * v_factor, 4));
        ELSIF p_capacidad_m3 IS NOT NULL THEN
            v_m3 := GREATEST(p_capacidad_m3, 0);
            v_lb := CASE
                WHEN v_factor > 0 THEN ROUND(v_m3 / v_factor, 4)
                ELSE COALESCE(p_capacidad_lb, 0)
            END;
        ELSE
            RETURN json_build_object('error', 'Indique capacidad m³ o lb', 'ok', FALSE);
        END IF;
    END IF;

    IF v_psi IS NOT NULL AND v_psi < v_psi_min THEN
        v_alerta_vacio := TRUE;
    END IF;

    IF COALESCE(v_m3, 0) <= 0 AND COALESCE(v_lb, 0) <= 0 THEN
        v_contenido := 'VACIO';
        v_m3 := 0;
        v_lb := 0;
    ELSIF v_cap_nom IS NOT NULL AND v_cap_nom > 0 AND COALESCE(v_m3, 0) >= (v_cap_nom * 0.98) THEN
        v_contenido := 'LLENO';
    ELSIF COALESCE(v_m3, 0) > 0 OR COALESCE(v_lb, 0) > 0 THEN
        v_contenido := 'DESCONOCIDO'; -- parcial medido
    ELSE
        v_contenido := 'VACIO';
    END IF;

    -- Umbral PSI fuerza vacío operativo
    IF v_alerta_vacio AND v_modo = 'FROM_PSI' THEN
        v_contenido := 'VACIO';
        v_m3 := 0;
        v_lb := 0;
    END IF;

    UPDATE bal_balon
    SET
        capacidad_restante = v_m3,
        capacidad_restante_lb = v_lb,
        presion_actual = COALESCE(v_psi, presion_actual),
        id_estado_contenido = COALESCE(bal_id_estado_contenido(v_contenido), id_estado_contenido),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'No se pudo actualizar el balón', 'ok', FALSE);
    END IF;

    RETURN json_build_object(
        'ok', TRUE,
        'capacidad_restante', v_m3,
        'capacidad_restante_lb', v_lb,
        'presion_actual', COALESCE(v_psi, (SELECT presion_actual FROM bal_balon WHERE id = p_id_balon)),
        'nombre_contenido', v_contenido,
        'factor_lb_m3', v_factor,
        'alerta_vacio_psi', v_alerta_vacio,
        'psi_minimo_util', v_psi_min
    );
END;
$function$;
