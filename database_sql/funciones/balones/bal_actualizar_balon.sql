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
    p_numero_serie VARCHAR DEFAULT NULL,
    p_id_marca_cilindro INTEGER DEFAULT NULL,
    p_id_organo_inspector INTEGER DEFAULT NULL,
    p_organo_inspector_no_aplica BOOLEAN DEFAULT NULL,
    p_anio_fabricacion SMALLINT DEFAULT NULL,
    p_mes_fabricacion SMALLINT DEFAULT NULL,
    p_id_planta INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo VARCHAR;
    v_numero_serie VARCHAR;
    v_anio_fabricacion SMALLINT;
    v_mes_fabricacion SMALLINT;
    v_fecha_fabricacion DATE;
    v_fecha_ultima_ph DATE;
    v_vigencia_ph INTEGER;
    v_fecha_proxima_ph DATE;
    v_id_tipo_balon INTEGER;
    v_tiene_historial_ph BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_mes_fabricacion IS NOT NULL AND (p_mes_fabricacion < 1 OR p_mes_fabricacion > 12) THEN
        RETURN json_build_object('error', 'El mes de fabricación debe estar entre 1 y 12', 'registro', NULL);
    END IF;

    IF p_id_planta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_planta AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La planta indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    v_codigo := NULLIF(TRIM(p_codigo_balon), '');

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_balon
        WHERE LOWER(TRIM(codigo_balon)) = LOWER(v_codigo) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro balón con el código ' || v_codigo, 'registro', NULL);
    END IF;

    SELECT
        COALESCE(p_anio_fabricacion, anio_fabricacion),
        COALESCE(p_mes_fabricacion, mes_fabricacion),
        COALESCE(p_fecha_fabricacion, fecha_fabricacion),
        COALESCE(p_fecha_ultima_prueba_hidrostatica, fecha_ultima_prueba_hidrostatica),
        COALESCE(p_vigencia_prueba_hidrostatica_anios, vigencia_prueba_hidrostatica_anios, 5),
        COALESCE(p_id_tipo_balon, id_tipo_balon),
        EXISTS (
            SELECT 1 FROM bal_balon_ph_historial h
            WHERE h.id_balon = bal_balon.id AND h.estado = 1
              AND COALESCE(h.observacion, '') NOT ILIKE 'PH calculado desde fabricación%'
        )
    INTO
        v_anio_fabricacion,
        v_mes_fabricacion,
        v_fecha_fabricacion,
        v_fecha_ultima_ph,
        v_vigencia_ph,
        v_id_tipo_balon,
        v_tiene_historial_ph
    FROM bal_balon
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_anio_fabricacion IS NOT NULL AND v_mes_fabricacion IS NOT NULL THEN
        v_fecha_fabricacion := make_date(v_anio_fabricacion::INT, v_mes_fabricacion::INT, 1);
    ELSIF v_fecha_fabricacion IS NOT NULL THEN
        v_fecha_fabricacion := make_date(
            EXTRACT(YEAR FROM v_fecha_fabricacion)::INT,
            EXTRACT(MONTH FROM v_fecha_fabricacion)::INT,
            1
        );
        v_anio_fabricacion := COALESCE(v_anio_fabricacion, EXTRACT(YEAR FROM v_fecha_fabricacion)::SMALLINT);
        v_mes_fabricacion := COALESCE(v_mes_fabricacion, EXTRACT(MONTH FROM v_fecha_fabricacion)::SMALLINT);
    END IF;

    IF v_id_tipo_balon IS NOT NULL THEN
        SELECT COALESCE(p_vigencia_prueba_hidrostatica_anios, tb.vigencia_ph_anios, v_vigencia_ph, 5)
        INTO v_vigencia_ph
        FROM bal_tipo_balon tb
        WHERE tb.id = v_id_tipo_balon;
    END IF;

    -- Recalcular PH desde fabricación solo si no hay historial real de pruebas
    IF p_fecha_ultima_prueba_hidrostatica IS NOT NULL THEN
        v_fecha_ultima_ph := make_date(
            EXTRACT(YEAR FROM p_fecha_ultima_prueba_hidrostatica)::INT,
            EXTRACT(MONTH FROM p_fecha_ultima_prueba_hidrostatica)::INT,
            1
        );
    ELSIF NOT v_tiene_historial_ph AND v_fecha_fabricacion IS NOT NULL THEN
        v_fecha_ultima_ph := v_fecha_fabricacion;
    ELSIF v_fecha_ultima_ph IS NOT NULL THEN
        v_fecha_ultima_ph := make_date(
            EXTRACT(YEAR FROM v_fecha_ultima_ph)::INT,
            EXTRACT(MONTH FROM v_fecha_ultima_ph)::INT,
            1
        );
    END IF;

    v_fecha_proxima_ph := COALESCE(
        CASE
            WHEN p_fecha_proxima_prueba_hidrostatica IS NOT NULL
            THEN make_date(
                EXTRACT(YEAR FROM p_fecha_proxima_prueba_hidrostatica)::INT,
                EXTRACT(MONTH FROM p_fecha_proxima_prueba_hidrostatica)::INT,
                1
            )
        END,
        CASE
            WHEN v_fecha_ultima_ph IS NOT NULL
            THEN (v_fecha_ultima_ph + make_interval(years => v_vigencia_ph))::DATE
        END
    );

    v_numero_serie := COALESCE(NULLIF(TRIM(p_numero_serie), ''), v_codigo);

    UPDATE bal_balon
    SET
        codigo_balon = COALESCE(v_codigo, codigo_balon),
        numero_serie = COALESCE(v_numero_serie, numero_serie),
        libro_cilindro = COALESCE(p_libro_cilindro, libro_cilindro),
        pagina_libro = COALESCE(p_pagina_libro, pagina_libro),
        fecha_registro = COALESCE(p_fecha_registro, fecha_registro),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_cliente_ubicacion = COALESCE(p_id_cliente_ubicacion, id_cliente_ubicacion),
        id_propietario = COALESCE(p_id_propietario, id_propietario),
        id_cliente_propietario = COALESCE(p_id_cliente_propietario, id_cliente_propietario),
        id_referencia = COALESCE(p_id_referencia, id_referencia),
        id_marca_cilindro = COALESCE(p_id_marca_cilindro, id_marca_cilindro),
        id_organo_inspector = COALESCE(p_id_organo_inspector, id_organo_inspector),
        organo_inspector_no_aplica = COALESCE(p_organo_inspector_no_aplica, organo_inspector_no_aplica),
        id_tipo_balon = COALESCE(p_id_tipo_balon, id_tipo_balon),
        id_producto_gas = COALESCE(p_id_producto_gas, id_producto_gas),
        id_estado_balon = COALESCE(p_id_estado_balon, id_estado_balon),
        id_planta = COALESCE(p_id_planta, id_planta),
        fecha_ultima_prueba_hidrostatica = COALESCE(v_fecha_ultima_ph, fecha_ultima_prueba_hidrostatica),
        vigencia_prueba_hidrostatica_anios = COALESCE(v_vigencia_ph, vigencia_prueba_hidrostatica_anios),
        fecha_proxima_prueba_hidrostatica = COALESCE(v_fecha_proxima_ph, fecha_proxima_prueba_hidrostatica),
        fecha_fabricacion = COALESCE(v_fecha_fabricacion, fecha_fabricacion),
        anio_fabricacion = COALESCE(v_anio_fabricacion, anio_fabricacion),
        mes_fabricacion = COALESCE(v_mes_fabricacion, mes_fabricacion),
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
