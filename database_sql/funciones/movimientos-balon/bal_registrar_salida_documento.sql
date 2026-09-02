-- Salida automática de cilindro vinculada a un documento (CPE / GRE / préstamo).
-- Idempotente por (id_balon, id_documento_ref, id_tipo_documento_ref) cuando hay doc.
-- Solo cambia custodia (estado/almacén/cliente) si el balón está EN_ALMACEN.
CREATE OR REPLACE FUNCTION bal_registrar_salida_documento(
    p_id_balon INTEGER,
    p_codigo_tipo_mov VARCHAR,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_codigo_tipo_doc_ref VARCHAR DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen_origen INTEGER DEFAULT NULL,
    p_codigo_estado_destino VARCHAR DEFAULT NULL,
    p_limpiar_almacen BOOLEAN DEFAULT TRUE,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
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
        p_fecha                     => NOW(),
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
$function$;
