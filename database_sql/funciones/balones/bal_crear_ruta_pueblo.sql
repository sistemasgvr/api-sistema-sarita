-- Crea ruta pueblo
DROP FUNCTION IF EXISTS public.bal_crear_ruta_pueblo (
  p_fecha date,
  p_id_almacen integer,
  p_id_usuario_responsable integer,
  p_id_chofer integer,
  p_factor_lb_m3 numeric,
  p_tolerancia_m3 numeric,
  p_observacion character varying,
  p_detalles json,
  p_id_usuario_auditoria integer,
  p_detalles_productos json
);

CREATE OR REPLACE FUNCTION public.bal_crear_ruta_pueblo (
  p_fecha date DEFAULT NULL::date,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_usuario_responsable integer DEFAULT NULL::integer,
  p_id_chofer integer DEFAULT NULL::integer,
  p_factor_lb_m3 numeric DEFAULT NULL::numeric,
  p_tolerancia_m3 numeric DEFAULT NULL::numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_detalles json DEFAULT '[]'::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_detalles_productos json DEFAULT '[]'::json
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_codigo_balon VARCHAR;
    v_balon_label TEXT;
    v_lb_salida NUMERIC;
    v_m3_salida NUMERIC;
    v_id_producto_gas INTEGER;
    v_unidad_gas VARCHAR;
    v_sellado BOOLEAN;
    v_item INTEGER := 0;
    v_balones INTEGER[] := ARRAY[]::INTEGER[];
    v_estado_balon VARCHAR;
    v_id_almacen_balon INTEGER;
    v_factor NUMERIC;
    v_tolerancia NUMERIC;
    v_det_producto JSON;
    v_id_producto INTEGER;
    v_cantidad_prod NUMERIC;
    v_producto_item INTEGER := 0;
    v_productos_ids INTEGER[] := ARRAY[]::INTEGER[];
    v_producto_estado INTEGER;
    v_producto_nombre VARCHAR;
    v_afecta_stock BOOLEAN;
    v_stock_actual NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1) THEN
        RETURN json_build_object('error', 'Almacén inválido', 'registro', NULL);
    END IF;

    IF (p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0)
       AND
       (p_detalles_productos IS NULL OR json_typeof(p_detalles_productos) <> 'array' OR json_array_length(p_detalles_productos) = 0)
    THEN
        RETURN json_build_object('error', 'Debe registrar al menos un cilindro o un producto', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'ABIERTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Estado ABIERTA no configurado', 'registro', NULL);
    END IF;

    SELECT COALESCE(
        NULLIF(p_tolerancia_m3, 0),
        e.tolerancia_m3_ruta_pueblo,
        0.5000
    )
    INTO v_tolerancia
    FROM gen_empresa e
    WHERE e.estado = 1
    ORDER BY e.id
    LIMIT 1;

    IF v_tolerancia IS NULL THEN
        v_tolerancia := COALESCE(NULLIF(p_tolerancia_m3, 0), 0.5000);
    END IF;

    IF p_detalles IS NOT NULL AND json_typeof(p_detalles) = 'array' THEN
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;
            v_id_balon := COALESCE(
                (v_detalle->>'idBalon')::INTEGER,
                (v_detalle->>'id_balon')::INTEGER
            );
            v_lb_salida := COALESCE(
                (v_detalle->>'lbSalida')::NUMERIC,
                (v_detalle->>'lb_salida')::NUMERIC
            );

            v_m3_salida := COALESCE((v_detalle->>'m3Salida')::NUMERIC, (v_detalle->>'m3_salida')::NUMERIC);
            IF v_m3_salida IS NULL OR v_m3_salida < 0 OR v_m3_salida::TEXT IN ('NaN', 'Infinity', '-Infinity')
               OR v_m3_salida <> ROUND(v_m3_salida, 4) THEN
                RAISE EXCEPTION 'Ítem %: ingresa los m³ de salida (≥ 0, hasta 4 decimales)', v_item;
            END IF;

            IF v_id_balon IS NULL THEN
                RAISE EXCEPTION 'Ítem %: cilindro obligatorio', v_item;
            END IF;

            IF v_lb_salida IS NULL OR v_lb_salida < 0 OR v_lb_salida::TEXT IN ('NaN', 'Infinity', '-Infinity') THEN
                RAISE EXCEPTION 'Ítem %: libras de salida inválidas', v_item;
            END IF;

            IF v_id_balon = ANY (v_balones) THEN
                RAISE EXCEPTION 'El cilindro % está duplicado en la ruta',
                    COALESCE((SELECT NULLIF(TRIM(codigo_balon), '') FROM bal_balon WHERE id = v_id_balon), v_id_balon::TEXT);
            END IF;
            v_balones := array_append(v_balones, v_id_balon);

            SELECT eb.nombre, b.id_almacen, b.codigo_balon, COALESCE(b.id_producto_gas, tb.id_gas)
            INTO v_estado_balon, v_id_almacen_balon, v_codigo_balon, v_id_producto_gas
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
            WHERE b.id = v_id_balon AND b.estado = 1
            FOR UPDATE OF b;

            IF v_estado_balon IS NULL THEN
                RAISE EXCEPTION 'Cilindro % no existe o está inactivo', v_id_balon;
            END IF;

            v_balon_label := COALESCE(NULLIF(TRIM(v_codigo_balon), ''), v_id_balon::TEXT);

            IF v_estado_balon NOT IN ('DISPONIBLE') THEN
                RAISE EXCEPTION 'Cilindro % debe estar en almacén (estado actual: %)', v_balon_label, v_estado_balon;
            END IF;

            IF v_id_almacen_balon IS DISTINCT FROM p_id_almacen THEN
                RAISE EXCEPTION 'Cilindro % no está en el almacén de la ruta', v_balon_label;
            END IF;

            SELECT UPPER(TRIM(um.nombre)) INTO v_unidad_gas
            FROM pro_producto p JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
            WHERE p.id = v_id_producto_gas AND p.estado = 1 AND p.es_gas AND p.afecta_stock;
            IF COALESCE(v_unidad_gas, '') NOT IN ('MT3', 'M3', 'M³') THEN
                RAISE EXCEPTION 'Cilindro %: configura un producto gas activo que afecte stock en m³.', v_balon_label;
            END IF;

            PERFORM bal_validar_capacidad_salida_ruta(v_id_balon, v_m3_salida);

            IF EXISTS (
                SELECT 1
                FROM bal_ruta_pueblo_detalle d
                INNER JOIN bal_ruta_pueblo r ON r.id = d.id_ruta_pueblo AND r.estado = 1
                INNER JOIN gen_lista_opciones er ON er.id = r.id_estado
                WHERE d.id_balon = v_id_balon
                  AND d.estado = 1
                  AND er.nombre IN ('ABIERTA', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'Cilindro % ya está en otra ruta abierta/en tránsito', v_balon_label;
            END IF;
        END LOOP;
    END IF;

    IF p_detalles_productos IS NOT NULL AND json_typeof(p_detalles_productos) = 'array' THEN
        FOR v_det_producto IN SELECT value FROM json_array_elements(p_detalles_productos)
        LOOP
            v_producto_item := v_producto_item + 1;
            v_id_producto := COALESCE(
                (v_det_producto->>'idProducto')::INTEGER,
                (v_det_producto->>'id_producto')::INTEGER
            );
            v_cantidad_prod := COALESCE(
                (v_det_producto->>'cantidad')::NUMERIC,
                0
            );

            IF v_id_producto IS NULL THEN
                RAISE EXCEPTION 'Ítem de producto %: producto obligatorio', v_producto_item;
            END IF;

            IF v_cantidad_prod IS NULL OR v_cantidad_prod <= 0 THEN
                RAISE EXCEPTION 'Ítem de producto %: cantidad inválida', v_producto_item;
            END IF;

            IF v_id_producto = ANY (v_productos_ids) THEN
                RAISE EXCEPTION 'El producto % está duplicado en la ruta', v_id_producto;
            END IF;
            v_productos_ids := array_append(v_productos_ids, v_id_producto);

            SELECT p.estado, p.nombre, COALESCE(p.afecta_stock, FALSE)
            INTO v_producto_estado, v_producto_nombre, v_afecta_stock
            FROM pro_producto p
            WHERE p.id = v_id_producto AND p.estado = 1;

            IF v_producto_estado IS NULL THEN
                RAISE EXCEPTION 'Producto % no existe o está inactivo', v_id_producto;
            END IF;

    -- INACTIVO 2026-10-31: Ruta pueblos es un registro histórico sin efecto en inventario.
    -- Conservar este bloque para una futura reactivación coordinada y conciliada.
    --             IF v_afecta_stock THEN
    --                 SELECT COALESCE(s.stock, 0) INTO v_stock_actual
    --                 FROM pro_stock s
    --                 WHERE s.id_almacen = p_id_almacen AND s.id_producto = v_id_producto AND s.estado = 1;
    --
    --                 IF COALESCE(v_stock_actual, 0) < v_cantidad_prod THEN
    --                     RAISE EXCEPTION 'Producto "%" (%): stock insuficiente (% disponible, % requerido)',
    --                         v_producto_nombre, v_id_producto, COALESCE(v_stock_actual, 0), v_cantidad_prod;
    --                 END IF;
    --             END IF;
        END LOOP;
    END IF;

    -- Conservamos la firma anterior; las lecturas manuales no usan un factor.
    v_factor := 0;

    INSERT INTO bal_ruta_pueblo (
        fecha, id_almacen, id_usuario_responsable, id_chofer,
        factor_lb_m3, tolerancia_m3, id_estado, observacion, control_gas_manual,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        COALESCE(p_fecha, CURRENT_DATE),
        p_id_almacen,
        p_id_usuario_responsable,
        p_id_chofer,
        v_factor,
        v_tolerancia,
        v_id_estado,
        NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        TRUE,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF p_detalles IS NOT NULL AND json_typeof(p_detalles) = 'array' THEN
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_balon := COALESCE(
                (v_detalle->>'idBalon')::INTEGER,
                (v_detalle->>'id_balon')::INTEGER
            );
            v_lb_salida := COALESCE(
                (v_detalle->>'lbSalida')::NUMERIC,
                (v_detalle->>'lb_salida')::NUMERIC
            );
            v_sellado := COALESCE(
                (v_detalle->>'sellado')::BOOLEAN,
                FALSE
            );

            v_m3_salida := COALESCE((v_detalle->>'m3Salida')::NUMERIC, (v_detalle->>'m3_salida')::NUMERIC);
            SELECT COALESCE(b.id_producto_gas, tb.id_gas) INTO v_id_producto_gas
            FROM bal_balon b LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            WHERE b.id = v_id_balon;
            INSERT INTO bal_ruta_pueblo_detalle (
                id_ruta_pueblo, id_balon, sellado, lb_salida, m3_salida, id_producto_gas, observacion,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                v_id_balon,
                v_sellado,
                v_lb_salida,
                v_m3_salida,
                v_id_producto_gas,
                NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_detalles_productos IS NOT NULL AND json_typeof(p_detalles_productos) = 'array' THEN
        FOR v_det_producto IN SELECT value FROM json_array_elements(p_detalles_productos)
        LOOP
            v_id_producto := COALESCE(
                (v_det_producto->>'idProducto')::INTEGER,
                (v_det_producto->>'id_producto')::INTEGER
            );
            v_cantidad_prod := COALESCE(
                (v_det_producto->>'cantidad')::NUMERIC,
                0
            );

            INSERT INTO bal_ruta_pueblo_detalle_producto (
                id_ruta_pueblo, id_producto, cantidad, observacion,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                v_id_producto,
                v_cantidad_prod,
                NULLIF(TRIM(COALESCE(v_det_producto->>'observacion', '')), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- INACTIVO 2026-10-31: Ruta pueblos es un registro histórico sin efecto en inventario.
    -- Conservar este bloque para una futura reactivación coordinada y conciliada.
    -- PERFORM bal_validar_stock_salida_ruta(v_id);

    RETURN bal_obtener_ruta_pueblo(v_id);
END;
$function$;
