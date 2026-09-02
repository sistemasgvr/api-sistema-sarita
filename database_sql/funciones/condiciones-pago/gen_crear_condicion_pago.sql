-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_condicion_pago
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.704Z
DROP FUNCTION IF EXISTS gen_crear_condicion_pago(p_codigo character varying, p_nombre character varying, p_dias_credito integer, p_numero_cuotas integer, p_dia_mes_pago integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_condicion_pago(p_codigo character varying, p_nombre character varying, p_dias_credito integer DEFAULT 0, p_numero_cuotas integer DEFAULT NULL::integer, p_dia_mes_pago integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_dias INTEGER;
    v_cuotas INTEGER;
    v_dia INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_dias := COALESCE(p_dias_credito, 0);
    v_cuotas := NULLIF(p_numero_cuotas, 0);
    v_dia := p_dia_mes_pago;

    IF v_dias < 0 THEN
        RETURN json_build_object('error', 'Los días de crédito no pueden ser negativos', 'registro', NULL);
    END IF;

    IF v_cuotas IS NOT NULL AND v_cuotas < 1 THEN
        RETURN json_build_object('error', 'El número de cuotas debe ser al menos 1', 'registro', NULL);
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
        -- Contado / crédito simple: no guardar día de cobro
        v_dia := NULL;
        IF COALESCE(v_cuotas, 0) <= 1 THEN
            v_cuotas := NULL;
        END IF;
    END IF;

    INSERT INTO gen_condicion_pago (
        codigo,
        nombre,
        dias_credito,
        numero_cuotas,
        dia_mes_pago,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        v_dias,
        v_cuotas,
        v_dia,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_condicion_pago(v_id);
END;
$function$
