DROP FUNCTION IF EXISTS cli_solicitar_reactivacion_cliente;

CREATE OR REPLACE FUNCTION cli_solicitar_reactivacion_cliente(
    p_id_cliente INTEGER,
    p_motivo_detalle VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_baja INTEGER;
    v_estado_cliente INT;
    v_id_pendiente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado_cliente FROM cli_clientes WHERE id = p_id_cliente;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe');
    END IF;

    IF v_estado_cliente = 1 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya está activo');
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    IF EXISTS (
        SELECT 1 FROM cli_baja_cliente
        WHERE id_cliente = p_id_cliente
          AND estado = 1
          AND id_estado_aprobacion = v_id_pendiente
          AND tipo_solicitud = 'REACTIVACION'
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya tiene una solicitud de reactivación pendiente');
    END IF;

    INSERT INTO cli_baja_cliente (
        id_cliente, tipo_solicitud, motivo_detalle,
        id_usuario_solicita, id_estado_aprobacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, 'REACTIVACION', NULLIF(TRIM(p_motivo_detalle), ''),
        p_id_usuario_auditoria, v_id_pendiente,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_baja;

    RETURN cli_obtener_baja_cliente(v_id_baja);
END;
$function$;
