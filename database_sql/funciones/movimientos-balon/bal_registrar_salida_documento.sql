-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_salida_documento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.600Z
DROP FUNCTION IF EXISTS bal_registrar_salida_documento(p_id_balon integer, p_codigo_tipo_mov character varying, p_id_documento_ref integer, p_codigo_tipo_doc_ref character varying, p_id_cliente integer, p_id_almacen_origen integer, p_codigo_estado_destino character varying, p_limpiar_almacen boolean, p_id_almacen_destino integer, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_registrar_salida_documento(p_id_balon integer, p_codigo_tipo_mov character varying, p_id_documento_ref integer DEFAULT NULL::integer, p_codigo_tipo_doc_ref character varying DEFAULT NULL::character varying, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen_origen integer DEFAULT NULL::integer, p_codigo_estado_destino character varying DEFAULT NULL::character varying, p_limpiar_almacen boolean DEFAULT true, p_id_almacen_destino integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
    v_creado BOOLEAN;
    v_nombre_estado_actual VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El cilindro es obligatorio', 'registro', NULL);
    END IF;

    IF p_codigo_tipo_mov IS NULL OR TRIM(p_codigo_tipo_mov) = '' THEN
        RETURN json_build_object('error', 'El tipo de movimiento es obligatorio', 'registro', NULL);
    END IF;

    SELECT eb.nombre INTO v_nombre_estado_actual
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado_actual, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error',
            'No se puede registrar salida de un cilindro dado de baja o reportado como robo',
            'registro',
            NULL
        );
    END IF;

    v_result := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => p_codigo_tipo_mov,
        p_fecha                     => LOCALTIMESTAMP,
        p_id_producto               => NULL,
        p_id_balon                  => p_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_origen         => COALESCE(p_id_almacen_origen,
            (SELECT id_almacen FROM bal_balon WHERE id = p_id_balon AND estado = 1)),
        p_id_almacen_destino        => p_id_almacen_destino,
        p_id_cliente                => p_id_cliente,
        p_codigo_tipo_documento_origen => p_codigo_tipo_doc_ref,
        p_id_documento_origen       => p_id_documento_ref,
        p_glosa                     => p_observacion,
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );

    v_creado := COALESCE((v_result->>'creado')::BOOLEAN, FALSE);

    -- Si la función creó el movimiento, lo retorna; si era idempotente, retorna el existente
    RETURN v_result;
END;
$function$
