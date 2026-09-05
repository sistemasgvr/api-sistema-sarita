-- Orden cronologico de movimientos, dueno del cilindro de garantia y
-- numeracion automatica de prestamos.
--
-- 1) inv_listar_movimientos: un solo flujo, del mas reciente al mas antiguo.
--    Los movimientos de PRODUCTO guardan `fecha` con la fecha del comprobante a
--    las 00:00, mientras que los de BALON guardan la hora real. Al ordenar por
--    `fecha` eso agrupaba todos los productos al inicio del dia y todos los
--    balones despues, que no es el orden en que ocurrieron. Se ordena por dia
--    calendario y, dentro del dia, por `fecha_creacion`, que si es el instante
--    real de las dos naturalezas. Afecta a la lista de movimientos y al
--    historial del detalle de stock, que consumen la misma funcion.
--
-- 2) El cilindro que un cliente deja en garantia perdia a su dueno.
--    bal_crear_balon anulaba `id_cliente_propietario` para cualquier propietario
--    distinto de 'CLIENTE', y el que usa el POS es 'GARANTIA_CLIENTE'. El POS si
--    enviaba el id del cliente de la venta; se perdia dentro de la funcion.
--    bal_actualizar_balon tenia el mismo problema al editar.
--
-- 3) Los prestamos nacian sin numero. bal_crear_prestamo solo guardaba
--    numero_prestamo si el llamador se lo pasaba, y el POS manda NULL. Ahora se
--    numera solo con el correlativo del anio (PRE-2026-001), con la misma
--    convencion de los alquileres (ALQ-2026-001).

-- ---------------------------------------------------------------------------
-- 1) inv_listar_movimientos
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS inv_listar_movimientos(p_busqueda character varying, p_limite integer, p_offset integer, p_naturaleza character varying, p_id_producto integer, p_id_balon integer, p_id_almacen integer, p_id_tipo_movimiento integer, p_id_tipo_documento_origen integer, p_id_documento_origen integer, p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION inv_listar_movimientos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_naturaleza character varying DEFAULT NULL::character varying, p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_tipo_movimiento integer DEFAULT NULL::integer, p_id_tipo_documento_origen integer DEFAULT NULL::integer, p_id_documento_origen integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        json_build_object(
            'total', COUNT(*),
            'producto', COUNT(*) FILTER (WHERE m.naturaleza = 'PRODUCTO'),
            'balon', COUNT(*) FILTER (WHERE m.naturaleza = 'BALON'),
            'salidas', COUNT(*) FILTER (WHERE COALESCE(inv_signo_tipo_movimiento(m.id_tipo_movimiento), 0) < 0),
            'entradas', COUNT(*) FILTER (WHERE COALESCE(inv_signo_tipo_movimiento(m.id_tipo_movimiento), 0) > 0)
        )
    INTO v_total, v_resumen
    FROM inv_movimiento m
    LEFT JOIN pro_producto p ON p.id = m.id_producto
    LEFT JOIN bal_balon b ON b.id = m.id_balon
    LEFT JOIN gen_almacen a ON a.id = m.id_almacen_origen
    LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
    WHERE m.estado = 1
      AND (p_naturaleza IS NULL OR m.naturaleza = UPPER(TRIM(p_naturaleza)))
      AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_almacen IS NULL OR m.id_almacen_origen = p_id_almacen OR m.id_almacen_destino = p_id_almacen)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_id_tipo_documento_origen IS NULL OR m.id_tipo_documento_origen = p_id_tipo_documento_origen)
      AND (p_id_documento_origen IS NULL OR m.id_documento_origen = p_id_documento_origen)
      AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.naturaleza,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            m.id_balon,
            b.numero_serie AS numero_serie_balon,
            m.cantidad,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.id_cliente,
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), ''),
                cli.numero_documento
            ) AS nombre_cliente,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_origen,
            m.id_tipo_documento_origen,
            tdo.nombre AS nombre_tipo_documento_origen,
            m.id_documento_detalle,
            m.id_movimiento_padre,
            (m.id_documento_origen IS NULL) AS puede_anular,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM inv_movimiento m
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN bal_balon b ON b.id = m.id_balon
        LEFT JOIN gen_lista_opciones umed ON umed.id = m.id_unidad_medida
        LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
        LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
        LEFT JOIN gen_almacen a ON a.id = m.id_almacen_origen
        LEFT JOIN cli_clientes cli ON cli.id = m.id_cliente
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        LEFT JOIN gen_lista_opciones tdo ON tdo.id = m.id_tipo_documento_origen
        LEFT JOIN auth_usuarios uc ON uc.id = m.id_usuario_creacion
        WHERE m.estado = 1
          AND (p_naturaleza IS NULL OR m.naturaleza = UPPER(TRIM(p_naturaleza)))
          AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_almacen IS NULL OR m.id_almacen_origen = p_id_almacen OR m.id_almacen_destino = p_id_almacen)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_id_tipo_documento_origen IS NULL OR m.id_tipo_documento_origen = p_id_tipo_documento_origen)
          AND (p_id_documento_origen IS NULL OR m.id_documento_origen = p_id_documento_origen)
          AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
          )
        ORDER BY m.fecha::DATE DESC, m.fecha_creacion DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2) El cilindro de garantia conserva a su dueno
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS bal_crear_balon(p_codigo_balon character varying, p_libro_cilindro character varying, p_pagina_libro integer, p_fecha_registro date, p_id_almacen integer, p_id_cliente_ubicacion integer, p_id_propietario integer, p_id_cliente_propietario integer, p_id_referencia integer, p_id_tipo_balon integer, p_id_producto_gas integer, p_id_estado_balon integer, p_fecha_ultima_prueba_hidrostatica date, p_vigencia_prueba_hidrostatica_anios integer, p_fecha_proxima_prueba_hidrostatica date, p_fecha_fabricacion date, p_numero_recepcion character varying, p_presion_actual numeric, p_observacion character varying, p_numero_serie character varying, p_id_marca_cilindro integer, p_id_organo_inspector integer, p_organo_inspector_no_aplica boolean, p_anio_fabricacion smallint, p_mes_fabricacion smallint, p_id_planta integer, p_tipo_valvula character varying, p_peso_aproximado_kg numeric, p_sello_inspeccion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_balon(p_codigo_balon character varying, p_libro_cilindro character varying DEFAULT NULL::character varying, p_pagina_libro integer DEFAULT NULL::integer, p_fecha_registro date DEFAULT NULL::date, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_propietario integer DEFAULT NULL::integer, p_id_cliente_propietario integer DEFAULT NULL::integer, p_id_referencia integer DEFAULT NULL::integer, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_fecha_ultima_prueba_hidrostatica date DEFAULT NULL::date, p_vigencia_prueba_hidrostatica_anios integer DEFAULT NULL::integer, p_fecha_proxima_prueba_hidrostatica date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_numero_recepcion character varying DEFAULT NULL::character varying, p_presion_actual numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_numero_serie character varying DEFAULT NULL::character varying, p_id_marca_cilindro integer DEFAULT NULL::integer, p_id_organo_inspector integer DEFAULT NULL::integer, p_organo_inspector_no_aplica boolean DEFAULT false, p_anio_fabricacion smallint DEFAULT NULL::smallint, p_mes_fabricacion smallint DEFAULT NULL::smallint, p_id_planta integer DEFAULT NULL::integer, p_tipo_valvula character varying DEFAULT NULL::character varying, p_peso_aproximado_kg numeric DEFAULT NULL::numeric, p_sello_inspeccion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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
    v_prop_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_codigo_balon IS NULL OR TRIM(p_codigo_balon) = '' THEN
        RETURN json_build_object('error', 'El código del balón es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_tipo_balon IS NULL THEN
        RETURN json_build_object('error', 'El tipo de balón es obligatorio', 'registro', NULL);
    END IF;

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object('error', 'El gas (producto) es obligatorio', 'registro', NULL);
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

    IF NOT EXISTS (
        SELECT 1 FROM bal_tipo_balon WHERE id = p_id_tipo_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto
        WHERE id = p_id_producto_gas AND estado = 1 AND es_gas = TRUE
    ) THEN
        RETURN json_build_object('error', 'El gas indicado no existe, está inactivo o no es un producto de gas', 'registro', NULL);
    END IF;

    IF p_mes_fabricacion IS NOT NULL AND (p_mes_fabricacion < 1 OR p_mes_fabricacion > 12) THEN
        RETURN json_build_object('error', 'El mes de fabricación debe estar entre 1 y 12', 'registro', NULL);
    END IF;

    IF p_id_planta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_planta AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La planta / proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Propiedad PLANTA exige proveedor concreto (id_planta); CLIENTE exige id_cliente_propietario.
    IF p_id_propietario IS NOT NULL THEN
        SELECT UPPER(glo.nombre) INTO v_prop_nombre
        FROM gen_lista_opciones glo
        WHERE glo.id = p_id_propietario;

        IF v_prop_nombre = 'PLANTA' AND p_id_planta IS NULL THEN
            RETURN json_build_object(
                'error', 'Si el propietario es planta, debe indicar el proveedor concreto (ej. Swiss Gas)',
                'registro', NULL
            );
        END IF;

        -- GARANTIA_CLIENTE es un cliente propietario igual que CLIENTE: el
        -- cilindro que alguien deja como colateral sigue siendo suyo, solo que
        -- en custodia de la empresa. Tratarlo aparte hacia que el id del cliente
        -- se perdiera y el balon quedara sin dueno.
        IF v_prop_nombre IN ('CLIENTE', 'GARANTIA_CLIENTE') AND p_id_cliente_propietario IS NULL THEN
            RETURN json_build_object(
                'error', 'Si el propietario es cliente, debe indicar el cliente propietario',
                'registro', NULL
            );
        END IF;

        IF v_prop_nombre IS DISTINCT FROM 'PLANTA' THEN
            p_id_planta := NULL;
        END IF;

        IF COALESCE(v_prop_nombre, '') NOT IN ('CLIENTE', 'GARANTIA_CLIENTE') THEN
            p_id_cliente_propietario := NULL;
        END IF;
    ELSIF p_id_planta IS NOT NULL THEN
        -- Planta sin propietario PLANTA: se ignora para no dejar datos inconsistentes.
        p_id_planta := NULL;
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
        numero_recepcion, presion_actual, observacion, tipo_valvula,
        peso_aproximado_kg, sello_inspeccion,
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
        NULLIF(TRIM(p_tipo_valvula), ''),
        p_peso_aproximado_kg,
        NULLIF(TRIM(p_sello_inspeccion), ''),
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

DROP FUNCTION IF EXISTS bal_actualizar_balon(p_id integer, p_codigo_balon character varying, p_libro_cilindro character varying, p_pagina_libro integer, p_fecha_registro date, p_id_almacen integer, p_id_cliente_ubicacion integer, p_id_propietario integer, p_id_cliente_propietario integer, p_id_referencia integer, p_id_tipo_balon integer, p_id_producto_gas integer, p_id_estado_balon integer, p_fecha_ultima_prueba_hidrostatica date, p_vigencia_prueba_hidrostatica_anios integer, p_fecha_proxima_prueba_hidrostatica date, p_fecha_fabricacion date, p_numero_recepcion character varying, p_presion_actual numeric, p_observacion character varying, p_numero_serie character varying, p_id_marca_cilindro integer, p_id_organo_inspector integer, p_organo_inspector_no_aplica boolean, p_anio_fabricacion smallint, p_mes_fabricacion smallint, p_id_planta integer, p_tipo_valvula character varying, p_peso_aproximado_kg numeric, p_sello_inspeccion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_balon(p_id integer, p_codigo_balon character varying DEFAULT NULL::character varying, p_libro_cilindro character varying DEFAULT NULL::character varying, p_pagina_libro integer DEFAULT NULL::integer, p_fecha_registro date DEFAULT NULL::date, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_propietario integer DEFAULT NULL::integer, p_id_cliente_propietario integer DEFAULT NULL::integer, p_id_referencia integer DEFAULT NULL::integer, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_fecha_ultima_prueba_hidrostatica date DEFAULT NULL::date, p_vigencia_prueba_hidrostatica_anios integer DEFAULT NULL::integer, p_fecha_proxima_prueba_hidrostatica date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_numero_recepcion character varying DEFAULT NULL::character varying, p_presion_actual numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_numero_serie character varying DEFAULT NULL::character varying, p_id_marca_cilindro integer DEFAULT NULL::integer, p_id_organo_inspector integer DEFAULT NULL::integer, p_organo_inspector_no_aplica boolean DEFAULT NULL::boolean, p_anio_fabricacion smallint DEFAULT NULL::smallint, p_mes_fabricacion smallint DEFAULT NULL::smallint, p_id_planta integer DEFAULT NULL::integer, p_tipo_valvula character varying DEFAULT NULL::character varying, p_peso_aproximado_kg numeric DEFAULT NULL::numeric, p_sello_inspeccion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
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
    v_id_propietario INTEGER;
    v_prop_nombre VARCHAR;
    v_id_planta INTEGER;
    v_id_cliente_propietario INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_mes_fabricacion IS NOT NULL AND (p_mes_fabricacion < 1 OR p_mes_fabricacion > 12) THEN
        RETURN json_build_object('error', 'El mes de fabricación debe estar entre 1 y 12', 'registro', NULL);
    END IF;

    IF p_id_planta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_planta AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La planta / proveedor indicado no existe o está inactivo', 'registro', NULL);
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

    -- Resolver propietario final y reglas PLANTA / CLIENTE.
    SELECT COALESCE(p_id_propietario, b.id_propietario)
    INTO v_id_propietario
    FROM bal_balon b
    WHERE b.id = p_id AND b.estado = 1;

    SELECT UPPER(glo.nombre) INTO v_prop_nombre
    FROM gen_lista_opciones glo
    WHERE glo.id = v_id_propietario;

    IF v_prop_nombre = 'PLANTA' THEN
        SELECT COALESCE(p_id_planta, b.id_planta)
        INTO v_id_planta
        FROM bal_balon b
        WHERE b.id = p_id AND b.estado = 1;

        -- Si el payload viene con propietario PLANTA y planta explícitamente vacía (formulario completo),
        -- exigir planta. Detectamos "intención de actualizar planta" cuando llega p_id_propietario
        -- o cuando p_id_planta no es null.
        IF p_id_propietario IS NOT NULL AND p_id_planta IS NULL THEN
            -- Cambio de propietario a PLANTA (o reenvío del form) sin planta: no heredar de otro tipo.
            SELECT CASE
                WHEN UPPER(COALESCE(prop.nombre, '')) = 'PLANTA' THEN b.id_planta
                ELSE NULL
            END
            INTO v_id_planta
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
            WHERE b.id = p_id AND b.estado = 1;
        END IF;

        IF v_id_planta IS NULL THEN
            RETURN json_build_object(
                'error', 'Si el propietario es planta, debe indicar el proveedor concreto (ej. Swiss Gas)',
                'registro', NULL
            );
        END IF;
        v_id_cliente_propietario := NULL;
    ELSIF v_prop_nombre IN ('CLIENTE', 'GARANTIA_CLIENTE') THEN
        SELECT COALESCE(p_id_cliente_propietario, b.id_cliente_propietario)
        INTO v_id_cliente_propietario
        FROM bal_balon b
        WHERE b.id = p_id AND b.estado = 1;

        IF p_id_propietario IS NOT NULL AND p_id_cliente_propietario IS NULL THEN
            SELECT CASE
                WHEN UPPER(COALESCE(prop.nombre, '')) IN ('CLIENTE', 'GARANTIA_CLIENTE')
                THEN b.id_cliente_propietario
                ELSE NULL
            END
            INTO v_id_cliente_propietario
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
            WHERE b.id = p_id AND b.estado = 1;
        END IF;

        IF v_id_cliente_propietario IS NULL THEN
            RETURN json_build_object(
                'error', 'Si el propietario es cliente, debe indicar el cliente propietario',
                'registro', NULL
            );
        END IF;
        v_id_planta := NULL;
    ELSE
        v_id_planta := NULL;
        v_id_cliente_propietario := NULL;
    END IF;

    IF v_id_tipo_balon IS NULL THEN
        RETURN json_build_object('error', 'El tipo de balón es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_tipo_balon WHERE id = v_id_tipo_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(p_id_producto_gas, (
        SELECT id_producto_gas FROM bal_balon WHERE id = p_id
    )) IS NULL THEN
        RETURN json_build_object('error', 'El gas (producto) es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto
        WHERE id = COALESCE(p_id_producto_gas, (
            SELECT id_producto_gas FROM bal_balon WHERE id = p_id
        ))
          AND estado = 1
          AND es_gas = TRUE
    ) THEN
        RETURN json_build_object(
            'error',
            'El gas indicado no existe, está inactivo o no es un producto de gas',
            'registro',
            NULL
        );
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
        id_cliente_propietario = v_id_cliente_propietario,
        id_referencia = COALESCE(p_id_referencia, id_referencia),
        id_marca_cilindro = COALESCE(p_id_marca_cilindro, id_marca_cilindro),
        id_organo_inspector = COALESCE(p_id_organo_inspector, id_organo_inspector),
        organo_inspector_no_aplica = COALESCE(p_organo_inspector_no_aplica, organo_inspector_no_aplica),
        id_tipo_balon = COALESCE(p_id_tipo_balon, id_tipo_balon),
        id_producto_gas = COALESCE(p_id_producto_gas, id_producto_gas),
        id_estado_balon = COALESCE(p_id_estado_balon, id_estado_balon),
        id_planta = v_id_planta,
        fecha_ultima_prueba_hidrostatica = COALESCE(v_fecha_ultima_ph, fecha_ultima_prueba_hidrostatica),
        vigencia_prueba_hidrostatica_anios = COALESCE(v_vigencia_ph, vigencia_prueba_hidrostatica_anios),
        fecha_proxima_prueba_hidrostatica = COALESCE(v_fecha_proxima_ph, fecha_proxima_prueba_hidrostatica),
        fecha_fabricacion = COALESCE(v_fecha_fabricacion, fecha_fabricacion),
        anio_fabricacion = COALESCE(v_anio_fabricacion, anio_fabricacion),
        mes_fabricacion = COALESCE(v_mes_fabricacion, mes_fabricacion),
        numero_recepcion = COALESCE(p_numero_recepcion, numero_recepcion),
        presion_actual = COALESCE(p_presion_actual, presion_actual),
        observacion = COALESCE(p_observacion, observacion),
        tipo_valvula = CASE
            WHEN p_tipo_valvula IS NULL THEN tipo_valvula
            ELSE NULLIF(TRIM(p_tipo_valvula), '')
        END,
        peso_aproximado_kg = COALESCE(p_peso_aproximado_kg, peso_aproximado_kg),
        sello_inspeccion = CASE
            WHEN p_sello_inspeccion IS NULL THEN sello_inspeccion
            ELSE NULLIF(TRIM(p_sello_inspeccion), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_balon(p_id);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3) Numeracion automatica de prestamos
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS bal_obtener_siguiente_numero_prestamo(p_anio integer);

CREATE OR REPLACE FUNCTION bal_obtener_siguiente_numero_prestamo(p_anio integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_prefijo VARCHAR;
    v_ultimo INTEGER;
    v_siguiente VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_anio := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER);
    v_prefijo := 'PRE-' || v_anio::TEXT || '-';

    -- Se mira el mayor correlativo ya usado en el anio, incluidos los prestamos
    -- cerrados o anulados, para no reutilizar un numero.
    SELECT COALESCE(
        MAX(
            NULLIF(
                REGEXP_REPLACE(UPPER(TRIM(numero_prestamo)), '^PRE-' || v_anio::TEXT || '-', ''),
                ''
            )::INTEGER
        ),
        0
    )
    INTO v_ultimo
    FROM bal_prestamo
    WHERE UPPER(TRIM(numero_prestamo)) ~ ('^PRE-' || v_anio::TEXT || '-[0-9]+$');

    v_siguiente := v_prefijo || LPAD((v_ultimo + 1)::TEXT, 3, '0');

    RETURN json_build_object(
        'error', NULL,
        'anio', v_anio,
        'ultimo', CASE WHEN v_ultimo = 0 THEN NULL ELSE v_prefijo || LPAD(v_ultimo::TEXT, 3, '0') END,
        'numero', v_siguiente
    );
EXCEPTION
    WHEN others THEN
        RETURN json_build_object(
            'error', 'No se pudo calcular el correlativo de prestamo',
            'numero', NULL
        );
END;
$function$;

DROP FUNCTION IF EXISTS bal_crear_prestamo(p_id_tipo_prestamo integer, p_numero_prestamo character varying, p_id_cliente integer, p_id_proveedor integer, p_id_almacen integer, p_fecha_salida date, p_fecha_retorno_pactada date, p_fecha_retorno_real date, p_titulo character varying, p_observacion character varying, p_id_estado integer, p_id_comprobante_venta integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_prestamo(p_id_tipo_prestamo integer, p_numero_prestamo character varying DEFAULT NULL::character varying, p_id_cliente integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_salida date DEFAULT NULL::date, p_fecha_retorno_pactada date DEFAULT NULL::date, p_fecha_retorno_real date DEFAULT NULL::date, p_titulo character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_nombre_tipo VARCHAR;
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_prestamo IS NULL THEN
        RETURN json_build_object('error', 'El tipo de préstamo es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.nombre
    INTO v_nombre_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_prestamo AND lo.estado = 1;

    IF v_nombre_tipo IS NULL THEN
        RETURN json_build_object('error', 'El tipo de préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Contraparte cliente: el código del tipo en TipoPrestamo incluye CLIENTE
    IF v_nombre_tipo ILIKE '%CLIENTE%' THEN
        IF p_id_cliente IS NULL THEN
            RETURN json_build_object('error', 'El cliente es obligatorio para este tipo de préstamo', 'registro', NULL);
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
        END IF;
    ELSIF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Los préstamos a cliente deben nacer de una venta (punto de venta).
    -- De esta forma el cilindro queda reservado y vinculado al comprobante.
    IF v_nombre_tipo ILIKE '%CLIENTE%' AND p_id_comprobante_venta IS NULL THEN
        RETURN json_build_object(
            'error',
            'Los préstamos a cliente deben estar vinculados a un comprobante de venta. Regístralos desde la venta en punto de venta.',
            'registro',
            NULL
        );
    END IF;

    -- Sin numero explicito se toma el correlativo del anio, igual que hacen los
    -- alquileres. Antes se guardaba NULL: el POS nunca manda numero, asi que
    -- todo prestamo nacido de una venta quedaba sin identificador y no habia
    -- como nombrarlo en el comprobante ni en el ticket.
    v_numero := NULLIF(TRIM(COALESCE(p_numero_prestamo, '')), '');
    IF v_numero IS NULL THEN
        v_numero := bal_obtener_siguiente_numero_prestamo()->>'numero';
    END IF;

    IF p_numero_prestamo IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_prestamo WHERE numero_prestamo = TRIM(p_numero_prestamo)
    ) THEN
        RETURN json_build_object('error', 'Ya existe un préstamo con el número ' || TRIM(p_numero_prestamo), 'registro', NULL);
    END IF;

    v_id_estado := p_id_estado;
    IF v_id_estado IS NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el estado ACTIVO del préstamo. Revise el catálogo EstadoPrestamo.',
                'registro',
                NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_prestamo (
        numero_prestamo, id_tipo_prestamo, id_cliente, id_proveedor, id_almacen,
        fecha_salida, fecha_retorno_pactada, fecha_retorno_real,
        titulo, observacion, id_estado,
        id_comprobante_venta, id_comprobante_compra,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_numero, p_id_tipo_prestamo, p_id_cliente, p_id_proveedor, p_id_almacen,
        p_fecha_salida, p_fecha_retorno_pactada, p_fecha_retorno_real,
        p_titulo, p_observacion, v_id_estado,
        p_id_comprobante_venta, p_id_comprobante_compra,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_prestamo(v_id);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4) Correccion de los datos que quedaron mal por los dos bugs de arriba
-- ---------------------------------------------------------------------------

-- Cilindros de garantia que quedaron sin dueno: se recupera el cliente desde el
-- prestamo donde figuran con rol GARANTIA. Solo toca filas sin dueno, asi que
-- reaplicarlo no cambia nada.
UPDATE bal_balon b
SET id_cliente_propietario = p.id_cliente,
    fecha_modificacion = NOW()
FROM bal_prestamo_detalle pd
JOIN bal_prestamo p ON p.id = pd.id_prestamo
WHERE pd.id_balon = b.id
  AND pd.rol = 'GARANTIA'
  AND pd.estado = 1
  AND b.id_cliente_propietario IS NULL
  AND p.id_cliente IS NOT NULL
  -- El propietario se comprueba con EXISTS y no con un JOIN del FROM: la tabla
  -- que se actualiza no se puede referenciar desde las condiciones de JOIN.
  AND EXISTS (
      SELECT 1
      FROM gen_lista_opciones prop
      JOIN gen_lista lprop ON lprop.id = prop.id_lista
      WHERE prop.id = b.id_propietario
        AND lprop.nombre = 'PropietarioBalon'
        AND prop.nombre = 'GARANTIA_CLIENTE'
  );

-- Prestamos existentes sin numero: se numeran por orden de creacion con el
-- correlativo del anio en que se crearon.
WITH sin_numero AS (
    SELECT
        p.id,
        EXTRACT(YEAR FROM COALESCE(p.fecha_salida, p.fecha_creacion))::INTEGER AS anio,
        ROW_NUMBER() OVER (
            PARTITION BY EXTRACT(YEAR FROM COALESCE(p.fecha_salida, p.fecha_creacion))::INTEGER
            ORDER BY p.id
        ) AS orden
    FROM bal_prestamo p
    WHERE NULLIF(TRIM(COALESCE(p.numero_prestamo, '')), '') IS NULL
),
base AS (
    SELECT
        s.anio,
        COALESCE(MAX(NULLIF(
            REGEXP_REPLACE(UPPER(TRIM(bp.numero_prestamo)), '^PRE-' || s.anio::TEXT || '-', ''), ''
        )::INTEGER), 0) AS ultimo
    FROM (SELECT DISTINCT anio FROM sin_numero) s
    LEFT JOIN bal_prestamo bp
        ON UPPER(TRIM(bp.numero_prestamo)) ~ ('^PRE-' || s.anio::TEXT || '-[0-9]+$')
    GROUP BY s.anio
)
UPDATE bal_prestamo p
SET numero_prestamo = 'PRE-' || sn.anio::TEXT || '-' || LPAD((b.ultimo + sn.orden)::TEXT, 3, '0'),
    fecha_modificacion = NOW()
FROM sin_numero sn
JOIN base b ON b.anio = sn.anio
WHERE p.id = sn.id;
