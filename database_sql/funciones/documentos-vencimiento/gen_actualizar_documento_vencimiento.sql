-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_documento_vencimiento
-- Overloads: 2
-- Generated: 2026-09-02T21:31:03.697Z
DROP FUNCTION IF EXISTS gen_actualizar_documento_vencimiento(p_id integer, p_id_categoria integer, p_descripcion character varying, p_id_vehiculo integer, p_fecha_vencimiento date, p_fecha_renovacion date, p_numero_documento character varying, p_observacion character varying, p_id_estado integer, p_id_usuario_auditoria integer, p_id_sucursal integer, p_reemplazar_alcance boolean);

CREATE OR REPLACE FUNCTION gen_actualizar_documento_vencimiento(p_id integer, p_id_categoria integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_id_vehiculo integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_renovacion date DEFAULT NULL::date, p_numero_documento character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_reemplazar_alcance boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_documento_vencimiento
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_vehiculo = CASE WHEN p_reemplazar_alcance THEN p_id_vehiculo ELSE COALESCE(p_id_vehiculo, id_vehiculo) END,
        id_sucursal = CASE WHEN p_reemplazar_alcance THEN p_id_sucursal ELSE COALESCE(p_id_sucursal, id_sucursal) END,
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        fecha_renovacion = COALESCE(p_fecha_renovacion, fecha_renovacion),
        numero_documento = COALESCE(p_numero_documento, numero_documento),
        observacion = COALESCE(p_observacion, observacion),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_documento_vencimiento(p_id);
END;
$function$

DROP FUNCTION IF EXISTS gen_actualizar_documento_vencimiento(p_id integer, p_id_categoria integer, p_descripcion character varying, p_id_vehiculo integer, p_fecha_vencimiento date, p_fecha_renovacion date, p_numero_documento character varying, p_observacion character varying, p_id_estado integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_documento_vencimiento(p_id integer, p_id_categoria integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_id_vehiculo integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_renovacion date DEFAULT NULL::date, p_numero_documento character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_documento_vencimiento
    SET
        id_categoria = COALESCE(p_id_categoria, id_categoria),
        descripcion = COALESCE(p_descripcion, descripcion),
        id_vehiculo = COALESCE(p_id_vehiculo, id_vehiculo),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        fecha_renovacion = COALESCE(p_fecha_renovacion, fecha_renovacion),
        numero_documento = COALESCE(p_numero_documento, numero_documento),
        observacion = COALESCE(p_observacion, observacion),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_documento_vencimiento(p_id);
END;
$function$
