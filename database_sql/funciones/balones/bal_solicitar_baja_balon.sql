-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_solicitar_baja_balon
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.606Z
DROP FUNCTION IF EXISTS bal_solicitar_baja_balon(p_id_balon integer, p_id_motivo_baja integer, p_id_usuario_solicita integer, p_motivo_detalle character varying, p_id_cliente_comprador integer, p_id_comprobante_venta integer, p_serie_comprobante character varying, p_numero_comprobante character varying, p_monto_venta numeric, p_observacion character varying, p_fecha_baja date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_solicitar_baja_balon(p_id_balon integer, p_id_motivo_baja integer, p_id_usuario_solicita integer, p_motivo_detalle character varying DEFAULT NULL::character varying, p_id_cliente_comprador integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_serie_comprobante character varying DEFAULT NULL::character varying, p_numero_comprobante character varying DEFAULT NULL::character varying, p_monto_venta numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_fecha_baja date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_baja INTEGER;
    v_nombre_motivo VARCHAR;
    v_id_estado_actual INTEGER;
    v_id_usuario INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_motivo_baja IS NULL THEN
        RETURN json_build_object('error', 'El motivo de baja es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_usuario_solicita IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el usuario solicitante', 'registro', NULL);
    END IF;

    SELECT id_estado_balon INTO v_id_estado_actual
    FROM bal_balon
    WHERE id = p_id_balon AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_baja_balon
        WHERE id_balon = p_id_balon
          AND estado = 1
          AND estado_aprobacion IN ('PENDIENTE', 'APROBADA')
    ) THEN
        RETURN json_build_object('error', 'El balón ya tiene una solicitud o baja activa', 'registro', NULL);
    END IF;

    SELECT lo.nombre
    INTO v_nombre_motivo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE lo.id = p_id_motivo_baja
      AND l.nombre = 'MotivoBajaBalon'
      AND lo.estado = 1;

    IF v_nombre_motivo IS NULL THEN
        RETURN json_build_object('error', 'El motivo de baja indicado no es válido', 'registro', NULL);
    END IF;

    IF v_nombre_motivo = 'OTROS' AND (p_motivo_detalle IS NULL OR TRIM(p_motivo_detalle) = '') THEN
        RETURN json_build_object('error', 'Debe indicar el detalle cuando el motivo de baja es OTROS', 'registro', NULL);
    END IF;

    v_id_usuario := COALESCE(p_id_usuario_auditoria, p_id_usuario_solicita);

    INSERT INTO bal_baja_balon (
        id_balon, id_motivo_baja, fecha_baja,
        id_usuario_solicita, estado_aprobacion,
        motivo_detalle, id_cliente_comprador, id_comprobante_venta,
        serie_comprobante, numero_comprobante, monto_venta, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_motivo_baja, COALESCE(p_fecha_baja, CURRENT_DATE),
        p_id_usuario_solicita, 'PENDIENTE',
        NULLIF(TRIM(p_motivo_detalle), ''), p_id_cliente_comprador, p_id_comprobante_venta,
        p_serie_comprobante, p_numero_comprobante, p_monto_venta, p_observacion,
        v_id_usuario,
        v_id_usuario
    )
    RETURNING id INTO v_id_baja;

    PERFORM bal_registrar_estado_historial(
        p_id_balon,
        'SOLICITUD_BAJA',
        v_id_baja,
        p_id_motivo_baja,
        v_id_estado_actual,
        NULL,
        COALESCE(NULLIF(TRIM(p_motivo_detalle), ''), NULLIF(TRIM(p_observacion), ''), 'Solicitud de baja'),
        v_id_usuario,
        NOW()
    );

    RETURN bal_obtener_baja_balon(v_id_baja);
END;
$function$
