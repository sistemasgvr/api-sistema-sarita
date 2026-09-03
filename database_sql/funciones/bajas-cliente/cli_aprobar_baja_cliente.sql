-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_aprobar_baja_cliente
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.951Z
DROP FUNCTION IF EXISTS cli_aprobar_baja_cliente(p_id_baja integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_aprobar_baja_cliente(p_id_baja integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_pendiente INTEGER;
    v_id_aprobada INTEGER;
    v_id_estado_actual INTEGER;
    v_id_cliente INTEGER;
    v_tipo_solicitud VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el administrador autorizador');
    END IF;

    -- Rol Administrador + permiso bajas_cliente.aprobar (o auth.todo). Permite auto-aprobación.
    IF NOT auth_usuario_es_admin_con_permiso(p_id_usuario_auditoria, 'bajas_cliente.aprobar') THEN
        RETURN json_build_object(
            'registro',
            NULL,
            'error',
            'La solicitud debe ser autorizada por un administrador con permiso de aprobar bajas de cliente'
        );
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    SELECT lo.id INTO v_id_aprobada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'APROBADA';

    SELECT
        bc.id_estado_aprobacion,
        bc.id_cliente,
        ts.nombre
    INTO
        v_id_estado_actual,
        v_id_cliente,
        v_tipo_solicitud
    FROM cli_baja_cliente bc
    LEFT JOIN gen_lista_opciones ts ON ts.id = bc.id_tipo_solicitud
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

    IF UPPER(COALESCE(v_tipo_solicitud, 'BAJA')) = 'REACTIVACION' THEN
        UPDATE cli_clientes
        SET
            estado = 1,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cliente;
    ELSE
        UPDATE cli_clientes
        SET
            estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cliente;
    END IF;

    RETURN cli_obtener_baja_cliente(p_id_baja);
END;
$function$;
