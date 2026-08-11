DROP FUNCTION IF EXISTS gen_actualizar_condicion_pago(INTEGER, VARCHAR, VARCHAR, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS gen_actualizar_condicion_pago(INTEGER, VARCHAR, VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_actualizar_condicion_pago(
    p_id INTEGER,
    p_codigo VARCHAR DEFAULT NULL,
    p_nombre VARCHAR DEFAULT NULL,
    p_dias_credito INTEGER DEFAULT NULL,
    p_numero_cuotas INTEGER DEFAULT NULL,
    p_dia_mes_pago INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_dias INTEGER;
    v_cuotas INTEGER;
    v_dia INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT
        COALESCE(p_dias_credito, dias_credito),
        NULLIF(COALESCE(p_numero_cuotas, numero_cuotas), 0),
        COALESCE(p_dia_mes_pago, dia_mes_pago)
    INTO v_dias, v_cuotas, v_dia
    FROM gen_condicion_pago
    WHERE id = p_id;

    -- Si el cliente envía explícitamente null de cuotas vía p_numero_cuotas = 0
    -- (Nest mapea "sin cuotas" a 0 o null). Preferimos: si p_numero_cuotas viene
    -- como NULL desde Nest significa "limpiar" solo cuando también se manda
    -- p_dias_credito (actualización completa del formulario).
    IF p_dias_credito IS NOT NULL THEN
        v_dias := p_dias_credito;
        v_cuotas := NULLIF(p_numero_cuotas, 0);
        v_dia := p_dia_mes_pago;
    END IF;

    IF v_dias < 0 THEN
        RETURN json_build_object('error', 'Los días de crédito no pueden ser negativos', 'registro', NULL);
    END IF;

    IF COALESCE(v_cuotas, 0) > 1 THEN
        IF v_dia IS NULL OR v_dia < 1 OR v_dia > 31 THEN
            RETURN json_build_object(
                'error',
                'En plan de cuotas debes indicar el día del mes a cobrar (1 a 31)',
                'registro',
                NULL
            );
        END IF;
    ELSE
        v_cuotas := NULL;
        v_dia := NULL;
    END IF;

    UPDATE gen_condicion_pago
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        dias_credito = v_dias,
        numero_cuotas = v_cuotas,
        dia_mes_pago = v_dia,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN gen_obtener_condicion_pago(p_id);
END;
$function$;
