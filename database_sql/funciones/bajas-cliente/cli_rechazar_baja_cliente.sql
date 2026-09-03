-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_rechazar_baja_cliente
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
DROP FUNCTION IF EXISTS cli_rechazar_baja_cliente(p_id_baja integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_rechazar_baja_cliente(p_id_baja integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_rechazada INTEGER;
    v_id_pendiente INTEGER;
    v_id_estado_actual INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el administrador que rechaza');
    END IF;

    IF NOT auth_usuario_es_admin_con_permiso(p_id_usuario_auditoria, 'bajas_cliente.rechazar')
       AND NOT auth_usuario_es_admin_con_permiso(p_id_usuario_auditoria, 'bajas_cliente.aprobar')
    THEN
        RETURN json_build_object(
            'registro',
            NULL,
            'error',
            'Solo un administrador con permiso de rechazar/aprobar bajas de cliente puede rechazar la solicitud'
        );
    END IF;

    SELECT lo.id INTO v_id_rechazada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'RECHAZADA';

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    SELECT bc.id_estado_aprobacion INTO v_id_estado_actual
    FROM cli_baja_cliente bc
    WHERE bc.id = p_id_baja AND bc.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La solicitud de baja no existe');
    END IF;

    IF v_id_estado_actual <> v_id_pendiente THEN
        RETURN json_build_object('registro', NULL, 'error', 'La solicitud ya fue procesada');
    END IF;

    UPDATE cli_baja_cliente
    SET
        id_estado_aprobacion = v_id_rechazada,
        id_usuario_autoriza = p_id_usuario_auditoria,
        fecha_autorizacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_baja;

    RETURN cli_obtener_baja_cliente(p_id_baja);
END;
$function$;
