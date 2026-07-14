CREATE OR REPLACE FUNCTION bal_crear_alquiler_detalle(
    p_id_alquiler INTEGER,
    p_id_balon INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_estado_alquilado INTEGER;
    v_mov_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El alquiler indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler_detalle
        WHERE id_alquiler = p_id_alquiler AND id_balon = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
    END IF;

    SELECT id_cliente, id_almacen
    INTO v_id_cliente, v_id_almacen
    FROM bal_alquiler
    WHERE id = p_id_alquiler AND estado = 1;

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_ALQUILER' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ALQUILER' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_alquilado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_alquiler_detalle (
        id_alquiler, id_balon,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_alquiler, p_id_balon,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF v_id_tipo_movimiento IS NOT NULL THEN
        v_mov_result := bal_crear_movimiento(
            p_id_balon,
            v_id_tipo_movimiento,
            p_id_alquiler,
            v_id_tipo_documento_ref,
            v_id_cliente,
            v_id_almacen,
            NULL,
            NOW(),
            'Salida por alquiler',
            p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;
    END IF;

    UPDATE bal_balon
    SET
        id_cliente_ubicacion = v_id_cliente,
        id_almacen = NULL,
        id_estado_balon = COALESCE(v_id_estado_alquilado, id_estado_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN bal_obtener_alquiler_detalle(v_id);
END;
$function$;
