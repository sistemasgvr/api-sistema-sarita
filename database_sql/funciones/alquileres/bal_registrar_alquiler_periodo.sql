-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_alquiler_periodo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.597Z
DROP FUNCTION IF EXISTS bal_registrar_alquiler_periodo(p_id_alquiler integer, p_fecha_inicio date, p_fecha_fin date, p_monto numeric, p_id_producto integer, p_id_comprobante integer, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_registrar_alquiler_periodo(p_id_alquiler integer, p_fecha_inicio date, p_fecha_fin date, p_monto numeric DEFAULT 0, p_id_producto integer DEFAULT NULL::integer, p_id_comprobante integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero INTEGER;
    v_id INTEGER;
    v_id_estado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1) THEN
        RETURN json_build_object('error', 'Alquiler no encontrado', 'registro', NULL);
    END IF;

    IF p_fecha_inicio IS NULL OR p_fecha_fin IS NULL THEN
        RETURN json_build_object('error', 'Fechas de periodo obligatorias', 'registro', NULL);
    END IF;

    IF p_fecha_fin < p_fecha_inicio THEN
        RETURN json_build_object('error', 'fecha_fin debe ser >= fecha_inicio', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(numero_periodo), 0) + 1 INTO v_numero
    FROM bal_alquiler_periodo
    WHERE id_alquiler = p_id_alquiler AND estado = 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoAlquilerPeriodo'
      AND lo.nombre = CASE WHEN p_id_comprobante IS NULL THEN 'PENDIENTE' ELSE 'COBRADO' END
      AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_alquiler_periodo (
        id_alquiler, numero_periodo, fecha_inicio, fecha_fin, monto,
        id_producto, id_comprobante, id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_alquiler, v_numero, p_fecha_inicio, p_fecha_fin, COALESCE(p_monto, 0),
        p_id_producto, p_id_comprobante, v_id_estado, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    UPDATE bal_alquiler
    SET
        fecha_fin_pactada = GREATEST(COALESCE(fecha_fin_pactada, p_fecha_fin), p_fecha_fin),
        fecha_modificacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id_alquiler;

    RETURN json_build_object(
        'registro', (
            SELECT row_to_json(t)
            FROM (
                SELECT p.*, pr.codigo AS codigo_producto, pr.nombre AS nombre_producto
                FROM bal_alquiler_periodo p
                LEFT JOIN pro_producto pr ON p.id_producto = pr.id
                WHERE p.id = v_id
            ) t
        )
    );
END;
$function$
