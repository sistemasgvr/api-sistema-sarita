-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_eliminar_logico_cliente
-- Overloads: 1
-- Updated: 2026-09-09 — bloquea si CxC con saldo > 0 o préstamos/alquileres ACTIVO
-- Updated: 2026-09-11 — bloquea si ven_garantia.monto_saldo > 0 activa
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

    IF EXISTS (
        SELECT 1
        FROM ven_garantia g
        WHERE g.id_cliente = p_id
          AND g.estado = 1
          AND COALESCE(g.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene garantías con saldo pendiente'
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
