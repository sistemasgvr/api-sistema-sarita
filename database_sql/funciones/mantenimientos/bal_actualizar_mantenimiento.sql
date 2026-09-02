-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.515Z
DROP FUNCTION IF EXISTS bal_actualizar_mantenimiento(p_id integer, p_id_tipo_mantenimiento integer, p_fecha_ingreso date, p_fecha_salida date, p_descripcion character varying, p_costo numeric, p_es_externo boolean, p_id_proveedor integer, p_id_estado integer, p_id_comprobante_venta integer, p_id_comprobante_compra integer, p_observacion character varying, p_id_usuario_auditoria integer, p_vigencia_ph_anios integer, p_id_organo_inspector integer, p_organo_inspector_no_aplica boolean, p_numero_certificado_ph character varying);

CREATE OR REPLACE FUNCTION bal_actualizar_mantenimiento(p_id integer, p_id_tipo_mantenimiento integer DEFAULT NULL::integer, p_fecha_ingreso date DEFAULT NULL::date, p_fecha_salida date DEFAULT NULL::date, p_descripcion character varying DEFAULT NULL::character varying, p_costo numeric DEFAULT NULL::numeric, p_es_externo boolean DEFAULT NULL::boolean, p_id_proveedor integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_vigencia_ph_anios integer DEFAULT NULL::integer, p_id_organo_inspector integer DEFAULT NULL::integer, p_organo_inspector_no_aplica boolean DEFAULT NULL::boolean, p_numero_certificado_ph character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_finalizado INTEGER;
    v_nombre_estado_actual VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT em.nombre
    INTO v_nombre_estado_actual
    FROM bal_mantenimiento m
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF UPPER(COALESCE(v_nombre_estado_actual, '')) = 'FINALIZADO' THEN
        RETURN json_build_object(
            'error', 'El mantenimiento finalizado no se puede editar. Use Finalizar solo para cerrar el ciclo.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_finalizado IS NOT NULL
       AND p_id_estado IS NOT NULL
       AND p_id_estado = v_id_estado_finalizado THEN
        RETURN json_build_object(
            'error', 'Para marcar como finalizado use la acción Finalizar (reingresa el cilindro).',
            'registro', NULL
        );
    END IF;

    UPDATE bal_mantenimiento
    SET
        id_tipo_mantenimiento = COALESCE(p_id_tipo_mantenimiento, id_tipo_mantenimiento),
        fecha_ingreso = COALESCE(p_fecha_ingreso, fecha_ingreso),
        fecha_salida = COALESCE(p_fecha_salida, fecha_salida),
        descripcion = COALESCE(p_descripcion, descripcion),
        costo = COALESCE(p_costo, costo),
        es_externo = COALESCE(p_es_externo, es_externo),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    PERFORM bal_sync_ph_desde_mantenimiento(
        p_id,
        p_id_usuario_auditoria,
        p_vigencia_ph_anios,
        p_id_organo_inspector,
        p_organo_inspector_no_aplica,
        p_numero_certificado_ph
    );

    RETURN bal_obtener_mantenimiento(p_id);
END;
$function$
