-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_aprobar_baja_cliente
-- Overloads: 1
-- Updated: 2026-09-09 — bloquea deudas en BAJA; cascada soft-delete/restaurar relacionados
-- Updated: 2026-09-11 — bloquea si ven_garantia.monto_saldo > 0 activa
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
    v_id_tipo_cobrar INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el administrador autorizador');
    END IF;

    -- Rol Administrador + permiso bajas_cliente.aprobar (o auth.todo). Usa el usuario de sesión (JWT).
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

    -- En BAJA: bloquear si hay deudas / préstamos / alquileres activos
    IF UPPER(COALESCE(v_tipo_solicitud, 'BAJA')) <> 'REACTIVACION' THEN
        SELECT glo.id INTO v_id_tipo_cobrar
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
        LIMIT 1;

        IF v_id_tipo_cobrar IS NOT NULL AND EXISTS (
            SELECT 1
            FROM fin_cuenta fc
            WHERE fc.id_tercero = v_id_cliente
              AND fc.id_tipo_cuenta = v_id_tipo_cobrar
              AND fc.estado = 1
              AND COALESCE(fc.monto_saldo, 0) > 0
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene cuentas por cobrar con saldo pendiente'
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo p
            JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
            WHERE p.id_cliente = v_id_cliente
              AND p.estado = 1
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene préstamos activos'
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler a
            JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
            WHERE a.id_cliente = v_id_cliente
              AND a.estado = 1
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene alquileres activos'
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM ven_garantia g
            WHERE g.id_cliente = v_id_cliente
              AND g.estado = 1
              AND COALESCE(g.monto_saldo, 0) > 0
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene garantías con saldo pendiente'
            );
        END IF;
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

        UPDATE cli_direcciones
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE gen_chofer
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE gen_vehiculo
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE gen_cuenta_bancaria
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE cli_contacto
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;
    ELSE
        UPDATE cli_clientes
        SET
            estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cliente;

        UPDATE cli_direcciones
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE gen_chofer
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE gen_vehiculo
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE gen_cuenta_bancaria
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE cli_contacto
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;
    END IF;

    RETURN cli_obtener_baja_cliente(p_id_baja);
END;
$function$;
