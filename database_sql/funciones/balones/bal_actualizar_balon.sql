CREATE OR REPLACE FUNCTION bal_actualizar_balon(
    p_id INTEGER,
    p_codigo_balon VARCHAR DEFAULT NULL,
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
    p_vigencia_prueba_hidrostatica_anios INTEGER DEFAULT NULL,
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
    v_codigo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := NULLIF(TRIM(p_codigo_balon), '');

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_balon
        WHERE LOWER(TRIM(codigo_balon)) = LOWER(v_codigo) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro balón con el código ' || v_codigo, 'registro', NULL);
    END IF;

    UPDATE bal_balon
    SET
        codigo_balon = COALESCE(v_codigo, codigo_balon),
        libro_cilindro = COALESCE(p_libro_cilindro, libro_cilindro),
        pagina_libro = COALESCE(p_pagina_libro, pagina_libro),
        fecha_registro = COALESCE(p_fecha_registro, fecha_registro),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_cliente_ubicacion = COALESCE(p_id_cliente_ubicacion, id_cliente_ubicacion),
        id_propietario = COALESCE(p_id_propietario, id_propietario),
        id_cliente_propietario = COALESCE(p_id_cliente_propietario, id_cliente_propietario),
        id_referencia = COALESCE(p_id_referencia, id_referencia),
        id_tipo_balon = COALESCE(p_id_tipo_balon, id_tipo_balon),
        id_producto_gas = COALESCE(p_id_producto_gas, id_producto_gas),
        id_estado_balon = COALESCE(p_id_estado_balon, id_estado_balon),
        fecha_ultima_prueba_hidrostatica = COALESCE(p_fecha_ultima_prueba_hidrostatica, fecha_ultima_prueba_hidrostatica),
        vigencia_prueba_hidrostatica_anios = COALESCE(p_vigencia_prueba_hidrostatica_anios, vigencia_prueba_hidrostatica_anios),
        fecha_proxima_prueba_hidrostatica = COALESCE(p_fecha_proxima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica),
        fecha_fabricacion = COALESCE(p_fecha_fabricacion, fecha_fabricacion),
        numero_recepcion = COALESCE(p_numero_recepcion, numero_recepcion),
        presion_actual = COALESCE(p_presion_actual, presion_actual),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_balon(p_id);
END;
$function$;
