-- ============================================================
-- Migracion: clientes/auth/bajas P0-P1 (deudas, cascada, sesiones)
-- Fecha: 2026-09-09
-- ============================================================

-- Function: cli_solicitar_baja_cliente
-- Updated: 2026-09-09 - bloquea si CxC con saldo > 0 o prestamos/alquileres ACTIVO
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
    v_id_tipo_cobrar INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado_cliente FROM cli_clientes WHERE id = p_id_cliente;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe');
    END IF;

    IF v_estado_cliente = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya está inactivo');
    END IF;

    SELECT glo.id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
    LIMIT 1;

    IF v_id_tipo_cobrar IS NOT NULL AND EXISTS (
        SELECT 1
        FROM fin_cuenta fc
        WHERE fc.id_tercero = p_id_cliente
          AND fc.id_tipo_cuenta = v_id_tipo_cobrar
          AND fc.estado = 1
          AND COALESCE(fc.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene cuentas por cobrar con saldo pendiente'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
        WHERE p.id_cliente = p_id_cliente
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene préstamos activos'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
        WHERE a.id_cliente = p_id_cliente
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene alquileres activos'
        );
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
$function$;

-- Function: cli_aprobar_baja_cliente
-- Updated: 2026-09-09 - bloquea deudas en BAJA; cascada soft-delete/restaurar relacionados
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

-- Function: cli_eliminar_logico_cliente
-- Updated: 2026-09-09 - bloquea si CxC con saldo > 0 o prestamos/alquileres ACTIVO
DROP FUNCTION IF EXISTS cli_eliminar_logico_cliente(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_eliminar_logico_cliente(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INT;
    v_id_tipo_cobrar INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado FROM cli_clientes WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id
        );
    END IF;

    IF v_estado = 0 THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id
        );
    END IF;

    SELECT glo.id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
    LIMIT 1;

    IF v_id_tipo_cobrar IS NOT NULL AND EXISTS (
        SELECT 1
        FROM fin_cuenta fc
        WHERE fc.id_tercero = p_id
          AND fc.id_tipo_cuenta = v_id_tipo_cobrar
          AND fc.estado = 1
          AND COALESCE(fc.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene cuentas por cobrar con saldo pendiente'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
        WHERE p.id_cliente = p_id
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene préstamos activos'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
        WHERE a.id_cliente = p_id
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene alquileres activos'
        );
    END IF;

    UPDATE cli_clientes
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    UPDATE cli_direcciones
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_chofer
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_vehiculo
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_cuenta_bancaria
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE cli_contacto
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    RETURN json_build_object(
        'eliminado', true,
        'id', p_id
    );
END;
$function$;

-- Function: auth_actualizar_usuario
-- Updated: 2026-09-09 - al cambiar contrasena cierra sesiones activas del usuario
DROP FUNCTION IF EXISTS auth_actualizar_usuario(p_id integer, p_nombre character varying, p_correo character varying, p_contrasena character varying, p_id_trabajador integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION auth_actualizar_usuario(p_id integer, p_nombre character varying DEFAULT NULL::character varying, p_correo character varying DEFAULT NULL::character varying, p_contrasena character varying DEFAULT NULL::character varying, p_id_trabajador integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE LOWER(correo) = LOWER(p_correo) AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE id_trabajador = p_id_trabajador AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El trabajador ya tiene otro usuario de acceso.', 'registro', NULL);
    END IF;

    UPDATE auth_usuarios
    SET
        nombre = COALESCE(p_nombre, nombre),
        correo = COALESCE(LOWER(p_correo), correo),
        contrasena = COALESCE(p_contrasena, contrasena),
        id_trabajador = COALESCE(p_id_trabajador, id_trabajador),
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_contrasena IS NOT NULL THEN
        UPDATE auth_sesiones
        SET
            estado = FALSE,
            fecha_fin = NOW()
        WHERE id_usuario = p_id
          AND estado = TRUE
          AND fecha_fin IS NULL;
    END IF;

    RETURN auth_obtener_usuario(p_id);
END;
$function$;
