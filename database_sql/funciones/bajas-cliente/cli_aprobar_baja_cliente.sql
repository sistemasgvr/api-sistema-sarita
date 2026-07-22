DROP FUNCTION IF EXISTS cli_aprobar_baja_cliente;

CREATE OR REPLACE FUNCTION cli_aprobar_baja_cliente(
    p_id_baja INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_tipo_solicitud VARCHAR(20);
    v_id_aprobada INTEGER;
    v_id_pendiente INTEGER;
    v_id_estado_actual INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_id_aprobada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'APROBADA';

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    SELECT bc.id_cliente, bc.id_estado_aprobacion, bc.tipo_solicitud
    INTO v_id_cliente, v_id_estado_actual, v_tipo_solicitud
    FROM cli_baja_cliente bc
    WHERE bc.id = p_id_baja AND bc.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La solicitud no existe');
    END IF;

    IF v_id_estado_actual <> v_id_pendiente THEN
        RETURN json_build_object('registro', NULL, 'error', 'La solicitud ya fue procesada');
    END IF;

    UPDATE cli_baja_cliente
    SET
        id_estado_aprobacion = v_id_aprobada,
        id_usuario_autoriza = p_id_usuario_auditoria,
        fecha_autorizacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_baja;

    IF v_tipo_solicitud = 'REACTIVACION' THEN
        PERFORM cli_restaurar_cliente(v_id_cliente, p_id_usuario_auditoria);
    ELSE
        PERFORM cli_eliminar_logico_cliente(v_id_cliente, p_id_usuario_auditoria);
    END IF;

    RETURN cli_obtener_baja_cliente(p_id_baja);
END;
$function$;
