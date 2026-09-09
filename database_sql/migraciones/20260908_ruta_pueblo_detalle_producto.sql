-- ============================================================
-- Migración: Ruta Pueblo — Detalle de productos
-- Fecha: 2026-09-08
--
-- Agrega soporte para productos en rutas a pueblos:
-- 1) Nueva tabla bal_ruta_pueblo_detalle_producto
-- 2) bal_crear_ruta_pueblo — recibe p_detalles_productos (JSON)
-- 3) bal_iniciar_ruta_pueblo — genera TRASLADO de productos
-- 4) bal_registrar_retorno_ruta_pueblo — retorno de productos
-- 5) bal_obtener_ruta_pueblo — incluye detalles de productos
-- ============================================================

-- 1) Nueva tabla para detalle de productos en ruta
CREATE TABLE IF NOT EXISTS bal_ruta_pueblo_detalle_producto (
    id SERIAL PRIMARY KEY,
    id_ruta_pueblo INTEGER NOT NULL REFERENCES bal_ruta_pueblo(id),
    id_producto INTEGER NOT NULL REFERENCES pro_producto(id),
    cantidad NUMERIC(12,4) NOT NULL CHECK (cantidad > 0),
    cantidad_retorno NUMERIC(12,4),
    observacion TEXT,
    id_usuario_creacion INTEGER,
    id_usuario_modificacion INTEGER,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP,
    estado INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_ruta_pueblo_det_producto_ruta
    ON bal_ruta_pueblo_detalle_producto(id_ruta_pueblo)
    WHERE estado = 1;

CREATE INDEX IF NOT EXISTS idx_ruta_pueblo_det_producto_producto
    ON bal_ruta_pueblo_detalle_producto(id_producto);

COMMENT ON TABLE bal_ruta_pueblo_detalle_producto IS 'Detalle de productos enviados en ruta a pueblos';
COMMENT ON COLUMN bal_ruta_pueblo_detalle_producto.cantidad_retorno IS 'Cantidad retornada al almacén (NULL = aún no retornado)';

-- ============================================================
-- 2) bal_crear_ruta_pueblo — recibe detalles de productos
-- ============================================================
DROP FUNCTION IF EXISTS bal_crear_ruta_pueblo(p_fecha date, p_id_almacen integer, p_id_usuario_responsable integer, p_id_chofer integer, p_factor_lb_m3 numeric, p_tolerancia_m3 numeric, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_ruta_pueblo(
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
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_lb_salida NUMERIC;
    v_sellado BOOLEAN;
    v_item INTEGER := 0;
    v_balones INTEGER[] := ARRAY[]::INTEGER[];
    v_estado_balon VARCHAR;
    v_id_almacen_balon INTEGER;
    v_factor NUMERIC;
    v_tolerancia NUMERIC;
    v_cap_m3 NUMERIC;
    v_cap_lb NUMERIC;
    v_factor_tipo NUMERIC;
    v_factores NUMERIC[] := ARRAY[]::NUMERIC[];
    v_nombre_tipo VARCHAR;
    -- Variables para productos
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

    -- Validar que haya al menos un cilindro o un producto
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

    -- Tolerancia: parámetro opcional o default de empresa
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

    -- Validar cilindros y derivar factor por tipo (capacidad m³ / capacidad lb)
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

            IF v_id_balon IS NULL THEN
                RAISE EXCEPTION 'Ítem %: cilindro obligatorio', v_item;
            END IF;

            IF v_lb_salida IS NULL OR v_lb_salida < 0 THEN
                RAISE EXCEPTION 'Ítem %: libras de salida inválidas', v_item;
            END IF;

            IF v_id_balon = ANY (v_balones) THEN
                RAISE EXCEPTION 'El cilindro % está duplicado en la ruta', v_id_balon;
            END IF;
            v_balones := array_append(v_balones, v_id_balon);

            SELECT eb.nombre, b.id_almacen, tb.capacidad, tb.capacidad_lb, tb.nombre
            INTO v_estado_balon, v_id_almacen_balon, v_cap_m3, v_cap_lb, v_nombre_tipo
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
            WHERE b.id = v_id_balon AND b.estado = 1;

            IF v_estado_balon IS NULL THEN
                RAISE EXCEPTION 'Cilindro % no existe o está inactivo', v_id_balon;
            END IF;

            IF v_estado_balon NOT IN ('DISPONIBLE') THEN
                RAISE EXCEPTION 'Cilindro % debe estar en almacén (estado actual: %)', v_id_balon, v_estado_balon;
            END IF;

            IF v_id_almacen_balon IS DISTINCT FROM p_id_almacen THEN
                RAISE EXCEPTION 'Cilindro % no está en el almacén de la ruta', v_id_balon;
            END IF;

            IF v_cap_m3 IS NULL OR v_cap_m3 <= 0 OR v_cap_lb IS NULL OR v_cap_lb <= 0 THEN
                RAISE EXCEPTION
                    'El tipo "%" del cilindro % no tiene capacidad m³ y lb configuradas. Edítalo en Tipos de balón.',
                    COALESCE(v_nombre_tipo, '(sin tipo)'),
                    v_id_balon;
            END IF;

            IF v_lb_salida > v_cap_lb THEN
                RAISE EXCEPTION
                    'Cilindro %: libras de salida (%.4f) no pueden superar la capacidad lb del tipo "%" (%.4f)',
                    v_id_balon,
                    v_lb_salida,
                    COALESCE(v_nombre_tipo, '(sin tipo)'),
                    v_cap_lb;
            END IF;

            v_factor_tipo := ROUND(v_cap_m3 / v_cap_lb, 6);
            v_factores := array_append(v_factores, v_factor_tipo);

            IF EXISTS (
                SELECT 1
                FROM bal_ruta_pueblo_detalle d
                INNER JOIN bal_ruta_pueblo r ON r.id = d.id_ruta_pueblo AND r.estado = 1
                INNER JOIN gen_lista_opciones er ON er.id = r.id_estado
                WHERE d.id_balon = v_id_balon
                  AND d.estado = 1
                  AND er.nombre IN ('ABIERTA', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'Cilindro % ya está en otra ruta abierta/en tránsito', v_id_balon;
            END IF;
        END LOOP;
    END IF;

    -- Validar productos
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

            -- Validar stock disponible si afecta_stock
            IF v_afecta_stock THEN
                SELECT COALESCE(s.stock, 0) INTO v_stock_actual
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen AND s.id_producto = v_id_producto AND s.estado = 1;

                IF COALESCE(v_stock_actual, 0) < v_cantidad_prod THEN
                    RAISE EXCEPTION 'Producto "%" (%): stock insuficiente (%.4f disponible, %.4f requerido)',
                        v_producto_nombre, v_id_producto, COALESCE(v_stock_actual, 0), v_cantidad_prod;
                END IF;
            END IF;
        END LOOP;
    END IF;

    -- Snapshot del factor: parámetro explícito o promedio de tipos de la ruta
    IF NULLIF(p_factor_lb_m3, 0) IS NOT NULL THEN
        v_factor := p_factor_lb_m3;
    ELSE
        SELECT ROUND(AVG(f), 6) INTO v_factor
        FROM unnest(v_factores) AS f;
    END IF;

    -- Si solo hay productos (sin cilindros), factor puede ser NULL
    IF v_factor IS NULL THEN
        v_factor := 0;
    END IF;

    INSERT INTO bal_ruta_pueblo (
        fecha, id_almacen, id_usuario_responsable, id_chofer,
        factor_lb_m3, tolerancia_m3, id_estado, observacion,
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
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Insertar detalles de cilindros
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

            INSERT INTO bal_ruta_pueblo_detalle (
                id_ruta_pueblo, id_balon, sellado, lb_salida, observacion,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                v_id_balon,
                v_sellado,
                v_lb_salida,
                NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    -- Insertar detalles de productos
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

    RETURN bal_obtener_ruta_pueblo(v_id);
END;
$function$;

-- ============================================================
-- 3) bal_iniciar_ruta_pueblo — genera TRASLADO de productos
-- ============================================================
DROP FUNCTION IF EXISTS bal_iniciar_ruta_pueblo(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_iniciar_ruta_pueblo(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_almacen INTEGER;
    v_id_estado_ruta INTEGER;
    v_det RECORD;
    v_mov JSON;
    v_det_prod RECORD;
    v_stock_record RECORD;
    v_stock_anterior NUMERIC;
    v_stock_nuevo NUMERIC;
    v_id_unidad_medida INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen
    INTO v_estado, v_id_almacen
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado <> 'ABIERTA' THEN
        RETURN json_build_object('error', 'Solo se puede iniciar una ruta ABIERTA', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo = p_id AND estado = 1
    ) AND NOT EXISTS (
        SELECT 1 FROM bal_ruta_pueblo_detalle_producto WHERE id_ruta_pueblo = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La ruta no tiene cilindros ni productos', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_ruta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    -- Mover cilindros (TRASLADO_LIMA)
    FOR v_det IN
        SELECT d.id_balon, d.lb_salida
        FROM bal_ruta_pueblo_detalle d
        WHERE d.id_ruta_pueblo = p_id AND d.estado = 1
    LOOP
        v_mov := bal_registrar_salida_documento(
            v_det.id_balon,
            'TRASLADO_LIMA',
            p_id,
            'RUTA_PUEBLO',
            NULL,
            v_id_almacen,
            'EN_RUTA_LIMA',
            TRUE,
            NULL,
            format('Salida ruta pueblos #%s · %.4f lb', p_id, v_det.lb_salida),
            p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'Cilindro %: %', v_det.id_balon, v_mov->>'error';
        END IF;

        UPDATE bal_balon
        SET
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_det.id_balon AND estado = 1;
    END LOOP;

    -- Mover productos (TRASLADO desde almacén)
    FOR v_det_prod IN
        SELECT dp.id_producto, dp.cantidad, p.nombre AS producto_nombre, p.afecta_stock
        FROM bal_ruta_pueblo_detalle_producto dp
        INNER JOIN pro_producto p ON p.id = dp.id_producto
        WHERE dp.id_ruta_pueblo = p_id AND dp.estado = 1
    LOOP
        IF COALESCE(v_det_prod.afecta_stock, FALSE) THEN
            -- Obtener stock anterior
            SELECT s.id, COALESCE(s.stock, 0) AS stock, pm.id AS id_unidad_medida
            INTO v_stock_record
            FROM pro_stock s
            INNER JOIN pro_producto pm ON pm.id = s.id_producto
            WHERE s.id_almacen = v_id_almacen
              AND s.id_producto = v_det_prod.id_producto
              AND s.estado = 1;

            IF v_stock_record IS NULL THEN
                RAISE EXCEPTION 'Producto "%" no tiene stock en el almacén de la ruta',
                    v_det_prod.producto_nombre;
            END IF;

            IF v_stock_record.stock < v_det_prod.cantidad THEN
                RAISE EXCEPTION 'Producto "%": stock insuficiente (%.4f disponible, %.4f requerido)',
                    v_det_prod.producto_nombre, v_stock_record.stock, v_det_prod.cantidad;
            END IF;

            v_stock_anterior := v_stock_record.stock;
            v_stock_nuevo := v_stock_anterior - v_det_prod.cantidad;
            v_id_unidad_medida := v_stock_record.id_unidad_medida;

            -- Descontar stock del almacén origen
            UPDATE pro_stock
            SET stock = v_stock_nuevo,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_stock_record.id;

            -- Registrar movimiento de inventario (TRASLADO de producto)
            INSERT INTO inv_movimiento (
                fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad,
                id_unidad_medida, id_almacen_origen, id_documento_origen,
                id_tipo_documento_origen, stock_anterior, stock_nuevo, glosa,
                id_usuario_creacion, id_usuario_modificacion
            )
            SELECT
                NOW(),
                lo.id,
                'PRODUCTO',
                v_det_prod.id_producto,
                v_det_prod.cantidad,
                v_id_unidad_medida,
                v_id_almacen,
                p_id,
                tdlo.id,
                v_stock_anterior,
                v_stock_nuevo,
                format('Salida ruta pueblos #%s · %.4f ud de %s', p_id, v_det_prod.cantidad, v_det_prod.producto_nombre),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            LEFT JOIN gen_lista_opciones tdlo ON tdlo.nombre = 'RUTA_PUEBLO'
                AND tdlo.id_lista = (SELECT id FROM gen_lista WHERE nombre = 'TipoDocumentoRef' LIMIT 1)
            WHERE l.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'TRASLADO' AND lo.estado = 1
            LIMIT 1;
        END IF;
    END LOOP;

    UPDATE bal_ruta_pueblo
    SET
        id_estado = v_id_estado_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;

-- ============================================================
-- 4) bal_registrar_retorno_ruta_pueblo — retorno de productos
-- ============================================================
DROP FUNCTION IF EXISTS bal_registrar_retorno_ruta_pueblo(p_id integer, p_detalles json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_registrar_retorno_ruta_pueblo(
    p_id integer,
    p_detalles json DEFAULT '[]'::json,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_detalles_productos json DEFAULT '[]'::json
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_almacen INTEGER;
    v_factor_ruta NUMERIC;
    v_factor NUMERIC;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_lb_retorno NUMERIC;
    v_id_det INTEGER;
    v_lb_salida NUMERIC;
    v_lb_retorno_existente NUMERIC;
    v_m3_delta NUMERIC;
    v_restante_m3 NUMERIC;
    v_mov JSON;
    v_cap_m3 NUMERIC;
    v_cap_lb NUMERIC;
    -- Variables para productos
    v_det_producto JSON;
    v_id_producto INTEGER;
    v_cantidad_retorno NUMERIC;
    v_id_det_prod INTEGER;
    v_cantidad_enviada NUMERIC;
    v_cantidad_retorno_existente NUMERIC;
    v_stock_record RECORD;
    v_stock_anterior NUMERIC;
    v_stock_nuevo NUMERIC;
    v_id_unidad_medida INTEGER;
    v_producto_nombre VARCHAR;
    v_afecta_stock BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen, r.factor_lb_m3
    INTO v_estado, v_id_almacen, v_factor_ruta
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado NOT IN ('EN_RUTA', 'ABIERTA') THEN
        RETURN json_build_object('error', 'Solo se registra retorno en rutas ABIERTA o EN_RUTA', 'registro', NULL);
    END IF;

    -- Si aún ABIERTA, iniciar primero (salida física)
    IF v_estado = 'ABIERTA' THEN
        PERFORM bal_iniciar_ruta_pueblo(p_id, p_id_usuario_auditoria);
        SELECT er.nombre, r.id_almacen, r.factor_lb_m3
        INTO v_estado, v_id_almacen, v_factor_ruta
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id = p_id AND r.estado = 1;
    END IF;

    -- Procesar retorno de cilindros
    IF p_detalles IS NOT NULL AND json_typeof(p_detalles) = 'array' AND json_array_length(p_detalles) > 0 THEN
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_balon := COALESCE(
                (v_detalle->>'idBalon')::INTEGER,
                (v_detalle->>'id_balon')::INTEGER
            );
            v_lb_retorno := COALESCE(
                (v_detalle->>'lbRetorno')::NUMERIC,
                (v_detalle->>'lb_retorno')::NUMERIC
            );

            IF v_id_balon IS NULL OR v_lb_retorno IS NULL OR v_lb_retorno < 0 THEN
                RAISE EXCEPTION 'Cada ítem requiere idBalon y lbRetorno ≥ 0';
            END IF;

            SELECT d.id, d.lb_salida, d.lb_retorno
            INTO v_id_det, v_lb_salida, v_lb_retorno_existente
            FROM bal_ruta_pueblo_detalle d
            WHERE d.id_ruta_pueblo = p_id
              AND d.id_balon = v_id_balon
              AND d.estado = 1;

            IF v_id_det IS NULL THEN
                RAISE EXCEPTION 'Cilindro % no pertenece a esta ruta', v_id_balon;
            END IF;

            -- Idempotente: no reprocesar cilindros ya retornados
            IF v_lb_retorno_existente IS NOT NULL THEN
                CONTINUE;
            END IF;

            IF v_lb_retorno > v_lb_salida THEN
                RAISE EXCEPTION 'Cilindro %: lb retorno (%.4f) no puede superar lb salida (%.4f)',
                    v_id_balon, v_lb_retorno, v_lb_salida;
            END IF;

            -- Factor por tipo del cilindro; fallback al snapshot de la ruta
            SELECT tb.capacidad, tb.capacidad_lb
            INTO v_cap_m3, v_cap_lb
            FROM bal_balon b
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
            WHERE b.id = v_id_balon AND b.estado = 1;

            IF v_cap_m3 IS NOT NULL AND v_cap_m3 > 0 AND v_cap_lb IS NOT NULL AND v_cap_lb > 0 THEN
                v_factor := ROUND(v_cap_m3 / v_cap_lb, 6);
            ELSE
                v_factor := COALESCE(v_factor_ruta, 0.317400);
            END IF;

            v_m3_delta := ROUND((v_lb_salida - v_lb_retorno) * v_factor, 4);
            v_restante_m3 := ROUND(v_lb_retorno * v_factor, 4);

            UPDATE bal_ruta_pueblo_detalle
            SET
                lb_retorno = v_lb_retorno,
                m3_delta = v_m3_delta,
                observacion = COALESCE(
                    NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                    observacion
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_det;

            -- Retorno a almacén con residual (CY4: no forzar vacío)
            v_mov := bal_registrar_salida_documento(
                v_id_balon,
                'RETORNO_LIMA',
                p_id,
                'RUTA_PUEBLO',
                NULL,
                NULL,
                'DISPONIBLE',
                FALSE,
                v_id_almacen,
                format('Retorno ruta pueblos #%s · %.4f lb residual', p_id, v_lb_retorno),
                p_id_usuario_auditoria
            );

            IF v_mov->>'error' IS NOT NULL THEN
                -- Si ya existe movimiento retorno idempotente, igual actualizamos balón
                NULL;
            END IF;

            UPDATE bal_balon
            SET
                id_almacen = v_id_almacen,
                id_cliente_ubicacion = NULL,
                id_estado_balon = (
                    SELECT lo.id
                    FROM gen_lista_opciones lo
                    INNER JOIN gen_lista l ON l.id = lo.id_lista
                    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon AND estado = 1;

        END LOOP;
    END IF;

    -- Procesar retorno de productos
    IF p_detalles_productos IS NOT NULL AND json_typeof(p_detalles_productos) = 'array' AND json_array_length(p_detalles_productos) > 0 THEN
        FOR v_det_producto IN SELECT value FROM json_array_elements(p_detalles_productos)
        LOOP
            v_id_producto := COALESCE(
                (v_det_producto->>'idProducto')::INTEGER,
                (v_det_producto->>'id_producto')::INTEGER
            );
            v_cantidad_retorno := COALESCE(
                (v_det_producto->>'cantidadRetorno')::NUMERIC,
                (v_det_producto->>'cantidad_retorno')::NUMERIC,
                (v_det_producto->>'cantidad')::NUMERIC,
                0
            );

            IF v_id_producto IS NULL THEN
                RAISE EXCEPTION 'Retorno de producto: idProducto obligatorio';
            END IF;

            IF v_cantidad_retorno < 0 THEN
                RAISE EXCEPTION 'Retorno de producto %: cantidad no puede ser negativa', v_id_producto;
            END IF;

            SELECT dp.id, dp.cantidad, dp.cantidad_retorno, p.nombre, COALESCE(p.afecta_stock, FALSE)
            INTO v_id_det_prod, v_cantidad_enviada, v_cantidad_retorno_existente, v_producto_nombre, v_afecta_stock
            FROM bal_ruta_pueblo_detalle_producto dp
            INNER JOIN pro_producto p ON p.id = dp.id_producto
            WHERE dp.id_ruta_pueblo = p_id
              AND dp.id_producto = v_id_producto
              AND dp.estado = 1;

            IF v_id_det_prod IS NULL THEN
                RAISE EXCEPTION 'Producto % no pertenece a esta ruta', v_id_producto;
            END IF;

            -- Idempotente: no reprocesar productos ya retornados
            IF v_cantidad_retorno_existente IS NOT NULL THEN
                CONTINUE;
            END IF;

            IF v_cantidad_retorno > v_cantidad_enviada THEN
                RAISE EXCEPTION 'Producto %: cantidad retorno (%.4f) no puede superar cantidad enviada (%.4f)',
                    v_producto_nombre, v_cantidad_retorno, v_cantidad_enviada;
            END IF;

            -- Actualizar retorno del producto
            UPDATE bal_ruta_pueblo_detalle_producto
            SET
                cantidad_retorno = v_cantidad_retorno,
                observacion = COALESCE(
                    NULLIF(TRIM(COALESCE(v_det_producto->>'observacion', '')), ''),
                    observacion
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_det_prod;

            -- Devolver stock al almacén si afecta_stock
            IF v_afecta_stock AND v_cantidad_retorno > 0 THEN
                SELECT s.id, COALESCE(s.stock, 0) AS stock, pm.id AS id_unidad_medida
                INTO v_stock_record
                FROM pro_stock s
                INNER JOIN pro_producto pm ON pm.id = s.id_producto
                WHERE s.id_almacen = v_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF v_stock_record IS NOT NULL THEN
                    v_stock_anterior := v_stock_record.stock;
                    v_stock_nuevo := v_stock_anterior + v_cantidad_retorno;
                    v_id_unidad_medida := v_stock_record.id_unidad_medida;

                    UPDATE pro_stock
                    SET stock = v_stock_nuevo,
                        id_usuario_modificacion = p_id_usuario_auditoria,
                        fecha_modificacion = NOW()
                    WHERE id = v_stock_record.id;

                    -- Registrar movimiento de retorno (ENTRADA)
                    INSERT INTO inv_movimiento (
                        fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad,
                        id_unidad_medida, id_almacen_origen, id_documento_origen,
                        id_tipo_documento_origen, stock_anterior, stock_nuevo, glosa,
                        id_usuario_creacion, id_usuario_modificacion
                    )
                    SELECT
                        NOW(),
                        lo.id,
                        'PRODUCTO',
                        v_id_producto,
                        v_cantidad_retorno,
                        v_id_unidad_medida,
                        v_id_almacen,
                        p_id,
                        tdlo.id,
                        v_stock_anterior,
                        v_stock_nuevo,
                        format('Retorno ruta pueblos #%s · %.4f ud de %s', p_id, v_cantidad_retorno, v_producto_nombre),
                        p_id_usuario_auditoria,
                        p_id_usuario_auditoria
                    FROM gen_lista_opciones lo
                    INNER JOIN gen_lista l ON l.id = lo.id_lista
                    LEFT JOIN gen_lista_opciones tdlo ON tdlo.nombre = 'RUTA_PUEBLO'
                        AND tdlo.id_lista = (SELECT id FROM gen_lista WHERE nombre = 'TipoDocumentoRef' LIMIT 1)
                    WHERE l.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
                    LIMIT 1;
                END IF;
            END IF;
        END LOOP;
    END IF;

    UPDATE bal_ruta_pueblo
    SET
        m3_calculado = (
            SELECT COALESCE(SUM(d.m3_delta), 0)
            FROM bal_ruta_pueblo_detalle d
            WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;

-- ============================================================
-- 5) bal_obtener_ruta_pueblo — incluye detalles de productos
-- ============================================================
DROP FUNCTION IF EXISTS bal_obtener_ruta_pueblo(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_ruta_pueblo(p_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_detalles_productos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            r.id,
            r.fecha,
            r.id_almacen,
            a.nombre AS nombre_almacen,
            r.id_usuario_responsable,
            u.nombre AS nombre_usuario_responsable,
            r.id_chofer,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer,
            r.factor_lb_m3,
            r.tolerancia_m3,
            r.m3_reportado_ventas,
            r.m3_calculado,
            r.descuadre_m3,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.observacion,
            r.fecha_creacion,
            r.fecha_modificacion
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_almacen a ON a.id = r.id_almacen
        LEFT JOIN auth_usuarios u ON u.id = r.id_usuario_responsable
        LEFT JOIN gen_chofer ch ON ch.id = r.id_chofer
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    -- Detalles de cilindros
    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON)
    INTO v_detalles
    FROM (
        SELECT
            det.id,
            det.id_ruta_pueblo,
            det.id_balon,
            b.codigo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad AS capacidad_tipo,
            tb.capacidad_lb AS capacidad_lb_tipo,
            bal_factor_lb_m3(tb.id, b.id_producto_gas) AS factor_lb_m3_tipo,
            det.sellado,
            det.lb_salida,
            det.lb_retorno,
            det.m3_delta,
            det.observacion
        FROM bal_ruta_pueblo_detalle det
        INNER JOIN bal_balon b ON b.id = det.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        WHERE det.id_ruta_pueblo = p_id AND det.estado = 1
    ) d;

    -- Detalles de productos
    SELECT COALESCE(json_agg(row_to_json(dp) ORDER BY dp.id), '[]'::JSON)
    INTO v_detalles_productos
    FROM (
        SELECT
            detp.id,
            detp.id_ruta_pueblo,
            detp.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            detp.cantidad,
            detp.cantidad_retorno,
            detp.observacion
        FROM bal_ruta_pueblo_detalle_producto detp
        INNER JOIN pro_producto p ON p.id = detp.id_producto
        WHERE detp.id_ruta_pueblo = p_id AND detp.estado = 1
    ) dp;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro::JSONB
            || jsonb_build_object('detalles', v_detalles)
            || jsonb_build_object('detalles_productos', v_detalles_productos)
        )::JSON
    );
END;
$function$;
