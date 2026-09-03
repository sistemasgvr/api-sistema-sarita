-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_documento_vencimiento
-- Overloads: 2
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_crear_documento_vencimiento(p_id_categoria integer, p_descripcion character varying, p_id_vehiculo integer, p_fecha_vencimiento date, p_fecha_renovacion date, p_numero_documento character varying, p_observacion character varying, p_id_estado integer, p_id_usuario_auditoria integer, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION gen_crear_documento_vencimiento(p_id_categoria integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_id_vehiculo integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_renovacion date DEFAULT NULL::date, p_numero_documento character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_documento_vencimiento (
        id_categoria,
        descripcion,
        id_vehiculo,
        id_sucursal,
        fecha_vencimiento,
        fecha_renovacion,
        numero_documento,
        observacion,
        id_estado,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_categoria,
        p_descripcion,
        p_id_vehiculo,
        p_id_sucursal,
        p_fecha_vencimiento,
        p_fecha_renovacion,
        p_numero_documento,
        p_observacion,
        p_id_estado,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_documento_vencimiento(v_id);
END;
$function$;

DROP FUNCTION IF EXISTS gen_crear_documento_vencimiento(p_id_categoria integer, p_descripcion character varying, p_id_vehiculo integer, p_fecha_vencimiento date, p_fecha_renovacion date, p_numero_documento character varying, p_observacion character varying, p_id_estado integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_documento_vencimiento(p_id_categoria integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_id_vehiculo integer DEFAULT NULL::integer, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_renovacion date DEFAULT NULL::date, p_numero_documento character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_documento_vencimiento (
        id_categoria,
        descripcion,
        id_vehiculo,
        fecha_vencimiento,
        fecha_renovacion,
        numero_documento,
        observacion,
        id_estado,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_categoria,
        p_descripcion,
        p_id_vehiculo,
        p_fecha_vencimiento,
        p_fecha_renovacion,
        p_numero_documento,
        p_observacion,
        p_id_estado,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_documento_vencimiento(v_id);
END;
$function$;
