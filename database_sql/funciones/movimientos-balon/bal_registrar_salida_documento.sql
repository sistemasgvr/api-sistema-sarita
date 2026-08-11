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
    v_id_movimiento INTEGER;
    v_id_tipo_mov INTEGER;
    v_id_tipo_doc INTEGER;
    v_id_estado_actual INTEGER;
    v_nombre_estado_actual VARCHAR;
    v_id_almacen_actual INTEGER;
    v_id_estado_destino INTEGER;
    v_en_almacen BOOLEAN := FALSE;
    v_almacen_origen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El cilindro es obligatorio', 'registro', NULL);
    END IF;

    IF p_codigo_tipo_mov IS NULL OR TRIM(p_codigo_tipo_mov) = '' THEN
        RETURN json_build_object('error', 'El tipo de movimiento es obligatorio', 'registro', NULL);
    END IF;

    SELECT b.id_estado_balon, b.id_almacen, eb.nombre
    INTO v_id_estado_actual, v_id_almacen_actual, v_nombre_estado_actual
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

    SELECT lo.id INTO v_id_tipo_mov
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon'
      AND lo.nombre = UPPER(TRIM(p_codigo_tipo_mov))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_mov IS NULL THEN
        RETURN json_build_object(
            'error',
            format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_mov))),
            'registro',
            NULL
        );
    END IF;

    IF p_codigo_tipo_doc_ref IS NOT NULL AND TRIM(p_codigo_tipo_doc_ref) <> '' THEN
        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_doc_ref))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_doc IS NULL THEN
            RETURN json_build_object(
                'error',
                format('Tipo de documento ref %s no configurado', UPPER(TRIM(p_codigo_tipo_doc_ref))),
                'registro',
                NULL
            );
        END IF;
    END IF;

    -- Idempotencia: mismo balón + mismo documento + mismo tipo de movimiento
    IF p_id_documento_ref IS NOT NULL AND v_id_tipo_doc IS NOT NULL THEN
        SELECT m.id INTO v_id_movimiento
        FROM bal_movimiento m
        WHERE m.estado = 1
          AND m.id_balon = p_id_balon
          AND m.id_documento_ref = p_id_documento_ref
          AND m.id_tipo_documento_ref = v_id_tipo_doc
          AND m.id_tipo_movimiento = v_id_tipo_mov
        ORDER BY m.id
        LIMIT 1;

        IF v_id_movimiento IS NOT NULL THEN
            RETURN bal_obtener_movimiento(v_id_movimiento);
        END IF;
    END IF;

    v_en_almacen := (COALESCE(v_nombre_estado_actual, '') = 'EN_ALMACEN');
    v_almacen_origen := COALESCE(p_id_almacen_origen, v_id_almacen_actual);

    INSERT INTO bal_movimiento (
        id_balon, id_tipo_movimiento, id_documento_ref, id_tipo_documento_ref,
        id_cliente, id_almacen_origen, id_almacen_destino,
        fecha_movimiento, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, v_id_tipo_mov, p_id_documento_ref, v_id_tipo_doc,
        p_id_cliente, v_almacen_origen, p_id_almacen_destino,
        NOW(), NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_movimiento;

    -- Solo mueve custodia si aún está en almacén (anti-doble con préstamo previo + GRE)
    IF p_codigo_estado_destino IS NOT NULL
       AND TRIM(p_codigo_estado_destino) <> ''
       AND v_en_almacen
    THEN
        SELECT lo.id INTO v_id_estado_destino
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon'
          AND lo.nombre = UPPER(TRIM(p_codigo_estado_destino))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_destino IS NULL THEN
            RETURN json_build_object(
                'error',
                format('Estado de cilindro %s no configurado', UPPER(TRIM(p_codigo_estado_destino))),
                'registro',
                NULL
            );
        END IF;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_destino,
            id_cliente_ubicacion = COALESCE(p_id_cliente, id_cliente_ubicacion),
            id_almacen = CASE
                WHEN p_limpiar_almacen THEN NULL
                ELSE COALESCE(p_id_almacen_destino, id_almacen)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    RETURN bal_obtener_movimiento(v_id_movimiento);
END;
$function$;
