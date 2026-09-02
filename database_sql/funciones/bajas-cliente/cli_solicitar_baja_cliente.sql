-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_solicitar_baja_cliente
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.628Z
DROP FUNCTION IF EXISTS cli_solicitar_baja_cliente(p_id_cliente integer, p_id_motivo_baja integer, p_motivo_detalle character varying, p_id_usuario_auditoria integer, p_id_tipo_solicitud integer);

CREATE OR REPLACE FUNCTION cli_solicitar_baja_cliente(p_id_cliente integer, p_id_motivo_baja integer DEFAULT NULL::integer, p_motivo_detalle character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_tipo_solicitud integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_baja INTEGER;
    v_estado_cliente INT;
    v_id_pendiente INTEGER;
    v_id_tipo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado_cliente FROM cli_clientes WHERE id = p_id_cliente;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe');
    END IF;

    IF v_estado_cliente = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya está inactivo');
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    v_id_tipo := COALESCE(p_id_tipo_solicitud, (SELECT lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoSolicitud' AND lo.nombre = 'BAJA'));

    IF EXISTS (
        SELECT 1 FROM cli_baja_cliente
        WHERE id_cliente = p_id_cliente
          AND estado = 1
          AND id_estado_aprobacion = v_id_pendiente
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya tiene una solicitud de baja pendiente');
    END IF;

    INSERT INTO cli_baja_cliente (
        id_cliente, id_motivo_baja, fecha_baja,
        id_usuario_solicita, id_estado_aprobacion,
        id_tipo_solicitud, motivo_detalle,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_id_motivo_baja, CURRENT_DATE,
        p_id_usuario_auditoria, v_id_pendiente,
        v_id_tipo, NULLIF(TRIM(p_motivo_detalle), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_baja;

    RETURN cli_obtener_baja_cliente(v_id_baja);
END;
$function$
