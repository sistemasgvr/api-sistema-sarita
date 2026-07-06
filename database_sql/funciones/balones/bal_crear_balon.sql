CREATE OR REPLACE FUNCTION bal_crear_balon(
    p_codigo_balon VARCHAR,
    p_libro_cilindro VARCHAR DEFAULT NULL,
    p_pagina_libro INTEGER DEFAULT NULL,
    p_fecha_registro DATE DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_cliente_ubicacion INTEGER DEFAULT NULL,
    p_id_propietario INTEGER DEFAULT NULL,
    p_id_cliente_propietario INTEGER DEFAULT NULL,
    p_id_referencia INTEGER DEFAULT NULL,
    p_id_tipo_balon INTEGER DEFAULT NULL,
    p_id_producto_gas INTEGER DEFAULT NULL,
    p_id_estado_balon INTEGER DEFAULT NULL,
    p_fecha_ultima_prueba_hidrostatica DATE DEFAULT NULL,
    p_vigencia_prueba_hidrostatica_anios INTEGER DEFAULT 5,
    p_fecha_proxima_prueba_hidrostatica DATE DEFAULT NULL,
    p_fecha_fabricacion DATE DEFAULT NULL,
    p_numero_recepcion VARCHAR DEFAULT NULL,
    p_presion_actual NUMERIC DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_codigo_balon IS NULL OR TRIM(p_codigo_balon) = '' THEN
        RETURN json_build_object('error', 'El código del balón es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_balon
        WHERE LOWER(TRIM(codigo_balon)) = LOWER(TRIM(p_codigo_balon))
    ) THEN
        RETURN json_build_object('error', 'Ya existe un balón con el código ' || TRIM(p_codigo_balon), 'registro', NULL);
    END IF;

    IF p_id_almacen IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_tipo_balon IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_tipo_balon WHERE id = p_id_tipo_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_balon (
        codigo_balon, libro_cilindro, pagina_libro, fecha_registro,
        id_almacen, id_cliente_ubicacion, id_propietario, id_cliente_propietario,
        id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
        fecha_ultima_prueba_hidrostatica, vigencia_prueba_hidrostatica_anios,
        fecha_proxima_prueba_hidrostatica, fecha_fabricacion, numero_recepcion,
        presion_actual, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        TRIM(p_codigo_balon), p_libro_cilindro, p_pagina_libro,
        COALESCE(p_fecha_registro, CURRENT_DATE),
        p_id_almacen, p_id_cliente_ubicacion, p_id_propietario, p_id_cliente_propietario,
        p_id_referencia, p_id_tipo_balon, p_id_producto_gas, p_id_estado_balon,
        p_fecha_ultima_prueba_hidrostatica, COALESCE(p_vigencia_prueba_hidrostatica_anios, 5),
        p_fecha_proxima_prueba_hidrostatica, p_fecha_fabricacion, p_numero_recepcion,
        p_presion_actual, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_balon(v_id);
END;
$function$;
