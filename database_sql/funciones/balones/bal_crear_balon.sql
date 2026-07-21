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
    p_vigencia_prueba_hidrostatica_anios INTEGER DEFAULT NULL,
    p_fecha_proxima_prueba_hidrostatica DATE DEFAULT NULL,
    p_fecha_fabricacion DATE DEFAULT NULL,
    p_numero_recepcion VARCHAR DEFAULT NULL,
    p_presion_actual NUMERIC DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_numero_serie VARCHAR DEFAULT NULL,
    p_id_marca_cilindro INTEGER DEFAULT NULL,
    p_id_organo_inspector INTEGER DEFAULT NULL,
    p_organo_inspector_no_aplica BOOLEAN DEFAULT FALSE,
    p_anio_fabricacion SMALLINT DEFAULT NULL,
    p_mes_fabricacion SMALLINT DEFAULT NULL,
    p_id_planta INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_numero_serie VARCHAR;
    v_anio_fabricacion SMALLINT;
    v_mes_fabricacion SMALLINT;
    v_fecha_fabricacion DATE;
    v_vigencia_ph INTEGER;
    v_fecha_ultima_ph DATE;
    v_fecha_proxima_ph DATE;
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

    IF p_mes_fabricacion IS NOT NULL AND (p_mes_fabricacion < 1 OR p_mes_fabricacion > 12) THEN
        RETURN json_build_object('error', 'El mes de fabricación debe estar entre 1 y 12', 'registro', NULL);
    END IF;

    IF p_id_planta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_planta AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La planta indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    v_numero_serie := COALESCE(NULLIF(TRIM(p_numero_serie), ''), TRIM(p_codigo_balon));

    v_anio_fabricacion := COALESCE(
        p_anio_fabricacion,
        CASE WHEN p_fecha_fabricacion IS NOT NULL THEN EXTRACT(YEAR FROM p_fecha_fabricacion)::SMALLINT END
    );
    v_mes_fabricacion := COALESCE(
        p_mes_fabricacion,
        CASE WHEN p_fecha_fabricacion IS NOT NULL THEN EXTRACT(MONTH FROM p_fecha_fabricacion)::SMALLINT END
    );

    IF v_anio_fabricacion IS NOT NULL AND v_mes_fabricacion IS NOT NULL THEN
        v_fecha_fabricacion := make_date(v_anio_fabricacion::INT, v_mes_fabricacion::INT, 1);
    ELSE
        v_fecha_fabricacion := CASE
            WHEN p_fecha_fabricacion IS NOT NULL
            THEN make_date(
                EXTRACT(YEAR FROM p_fecha_fabricacion)::INT,
                EXTRACT(MONTH FROM p_fecha_fabricacion)::INT,
                1
            )
            ELSE NULL
        END;
    END IF;

    v_vigencia_ph := COALESCE(p_vigencia_prueba_hidrostatica_anios, 5);

    IF p_id_tipo_balon IS NOT NULL THEN
        SELECT COALESCE(p_vigencia_prueba_hidrostatica_anios, tb.vigencia_ph_anios, 5)
        INTO v_vigencia_ph
        FROM bal_tipo_balon tb
        WHERE tb.id = p_id_tipo_balon;
    END IF;

    -- Base PH: última prueba explícita, o fabricación (mes/año del lomo) + vigencia del tipo/gas
    v_fecha_ultima_ph := CASE
        WHEN p_fecha_ultima_prueba_hidrostatica IS NOT NULL
        THEN make_date(
            EXTRACT(YEAR FROM p_fecha_ultima_prueba_hidrostatica)::INT,
            EXTRACT(MONTH FROM p_fecha_ultima_prueba_hidrostatica)::INT,
            1
        )
        ELSE v_fecha_fabricacion
    END;

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

    INSERT INTO bal_balon (
        codigo_balon, numero_serie, libro_cilindro, pagina_libro, fecha_registro,
        id_almacen, id_cliente_ubicacion, id_propietario, id_cliente_propietario,
        id_referencia, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
        id_tipo_balon, id_producto_gas, id_estado_balon, id_planta,
        fecha_ultima_prueba_hidrostatica, vigencia_prueba_hidrostatica_anios,
        fecha_proxima_prueba_hidrostatica, fecha_fabricacion, anio_fabricacion, mes_fabricacion,
        numero_recepcion, presion_actual, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        TRIM(p_codigo_balon), v_numero_serie, p_libro_cilindro, p_pagina_libro,
        COALESCE(p_fecha_registro, CURRENT_DATE),
        p_id_almacen, p_id_cliente_ubicacion, p_id_propietario, p_id_cliente_propietario,
        p_id_referencia, p_id_marca_cilindro, p_id_organo_inspector,
        COALESCE(p_organo_inspector_no_aplica, FALSE),
        p_id_tipo_balon, p_id_producto_gas, p_id_estado_balon, p_id_planta,
        v_fecha_ultima_ph, v_vigencia_ph,
        v_fecha_proxima_ph, v_fecha_fabricacion, v_anio_fabricacion, v_mes_fabricacion,
        p_numero_recepcion, p_presion_actual, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF v_fecha_ultima_ph IS NOT NULL THEN
        PERFORM bal_registrar_ph_historial(
            v_id,
            v_fecha_ultima_ph,
            v_vigencia_ph,
            p_id_organo_inspector,
            COALESCE(p_organo_inspector_no_aplica, FALSE),
            NULL,
            NULL,
            NULL,
            CASE
                WHEN p_fecha_ultima_prueba_hidrostatica IS NOT NULL THEN 'Registro inicial de PH'
                ELSE 'PH calculado desde fabricación (mes/año)'
            END,
            p_id_usuario_auditoria
        );
    END IF;

    RETURN bal_obtener_balon(v_id);
END;
$function$;
