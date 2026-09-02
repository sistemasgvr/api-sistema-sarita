-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_renovar_alquiler
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.601Z
DROP FUNCTION IF EXISTS bal_renovar_alquiler(p_id_alquiler integer, p_id_comprobante integer, p_monto numeric, p_fecha_inicio date, p_fecha_fin date, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_renovar_alquiler(p_id_alquiler integer, p_id_comprobante integer, p_monto numeric DEFAULT NULL::numeric, p_fecha_inicio date DEFAULT NULL::date, p_fecha_fin date DEFAULT NULL::date, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_alq RECORD;
    v_ultimo RECORD;
    v_inicio DATE;
    v_fin DATE;
    v_monto NUMERIC;
    v_dias INTEGER;
    v_periodo JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_alq
    FROM bal_alquiler
    WHERE id = p_id_alquiler AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Alquiler no encontrado', 'registro', NULL);
    END IF;

    IF v_alq.id_producto_regulador IS NULL THEN
        RETURN json_build_object(
            'error', 'El alquiler no tiene regulador vinculado; no se puede renovar',
            'registro', NULL
        );
    END IF;

    IF p_id_comprobante IS NULL OR NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Comprobante de renovación inválido', 'registro', NULL);
    END IF;

    SELECT * INTO v_ultimo
    FROM bal_alquiler_periodo
    WHERE id_alquiler = p_id_alquiler AND estado = 1
    ORDER BY numero_periodo DESC
    LIMIT 1;

    v_dias := COALESCE(NULLIF(v_alq.dias_periodo, 0), 14);
    v_inicio := COALESCE(p_fecha_inicio, CASE
        WHEN v_ultimo.id IS NOT NULL THEN (v_ultimo.fecha_fin + 1)
        ELSE COALESCE(v_alq.fecha_fin_pactada, CURRENT_DATE) + 1
    END);
    v_fin := COALESCE(p_fecha_fin, v_inicio + (v_dias - 1));
    v_monto := COALESCE(p_monto, v_alq.tarifa_diaria, 0);

    v_periodo := bal_registrar_alquiler_periodo(
        p_id_alquiler,
        v_inicio,
        v_fin,
        v_monto,
        v_alq.id_producto_regulador,
        p_id_comprobante,
        COALESCE(p_observacion, 'Renovación regulador'),
        p_id_usuario_auditoria
    );

    IF (v_periodo->>'error') IS NOT NULL THEN
        RETURN v_periodo;
    END IF;

    UPDATE bal_alquiler
    SET
        total_cobrado = COALESCE(total_cobrado, 0) + v_monto,
        fecha_fin_pactada = v_fin,
        fecha_modificacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id_alquiler;

    RETURN bal_obtener_alquiler(p_id_alquiler);
END;
$function$
