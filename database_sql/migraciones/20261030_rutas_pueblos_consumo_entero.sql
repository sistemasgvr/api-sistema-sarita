-- Rutas: unidades de conversión, errores de movimiento y truncamiento del consumo total.
-- No modifica rutas históricas ni el stock del producto gas. Aplicar junto con el admin actualizado.
-- Fuente: funciones/balones/bal_{factor_ruta_balon,obtener_ruta_pueblo,crear_ruta_pueblo,
-- iniciar_ruta_pueblo,registrar_retorno_ruta_pueblo,cerrar_ruta_pueblo}.sql
BEGIN;

-- Conversión estricta para rutas: capacidad nominal en su unidad a m³/lb de gas.
CREATE OR REPLACE FUNCTION public.bal_factor_ruta_balon(p_id_balon integer, p_validar boolean DEFAULT true)
RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_d RECORD;
    v_cap_m3 NUMERIC;
BEGIN
    SELECT b.codigo_balon, tb.nombre AS tipo, tb.capacidad, tb.capacidad_lb,
           UPPER(TRIM(um.nombre)) AS unidad, p.factor_kg_m3, p.factor_lb_m3
    INTO v_d
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
    LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
    LEFT JOIN pro_producto p ON p.id = COALESCE(b.id_producto_gas, tb.id_gas) AND p.estado = 1
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cilindro % no existe o está inactivo', p_id_balon;
    END IF;
    IF COALESCE(v_d.capacidad, 0) <= 0 OR COALESCE(v_d.capacidad_lb, 0) <= 0 THEN
        RAISE EXCEPTION 'Cilindro %: configura la capacidad nominal, su unidad y las libras de gas lleno en el tipo "%".',
            v_d.codigo_balon, COALESCE(v_d.tipo, '(sin tipo)');
    END IF;

    IF v_d.unidad IN ('MT3', 'M3', 'M³') THEN
        v_cap_m3 := v_d.capacidad;
    ELSIF v_d.unidad IN ('KG', 'KGM') THEN
        IF COALESCE(v_d.factor_kg_m3, 0) <= 0 THEN
            RAISE EXCEPTION 'Cilindro %: configura el factor de kg a m³ del producto gas para convertir la capacidad de su tipo (% kg).',
                v_d.codigo_balon, v_d.capacidad;
        END IF;
        v_cap_m3 := v_d.capacidad * v_d.factor_kg_m3;
    ELSIF v_d.unidad = 'LB' THEN
        IF COALESCE(v_d.factor_lb_m3, 0) <= 0 THEN
            RAISE EXCEPTION 'Cilindro %: configura el factor de lb a m³ del producto gas.', v_d.codigo_balon;
        END IF;
        v_cap_m3 := v_d.capacidad * v_d.factor_lb_m3;
    ELSE
        RAISE EXCEPTION 'Cilindro %: la unidad "%" del tipo "%" no permite calcular m³. Configura m³, kg o lb y su equivalencia.',
            v_d.codigo_balon, COALESCE(v_d.unidad, '(sin unidad)'), v_d.tipo;
    END IF;
    RETURN v_cap_m3 / v_d.capacidad_lb;
EXCEPTION WHEN raise_exception THEN
    IF p_validar THEN RAISE; END IF;
    RETURN NULL;
END;
$function$;


-- Obtiene ruta pueblo por id
CREATE OR REPLACE FUNCTION public.bal_obtener_ruta_pueblo (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_detalles_productos JSON;
    v_m3_exacto NUMERIC;
    v_m3_registrado NUMERIC;
    v_ajuste_m3 NUMERIC;
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
            um.nombre AS unidad_capacidad_tipo,
            bal_factor_ruta_balon(b.id, FALSE) AS factor_lb_m3_tipo,
            det.sellado,
            det.lb_salida,
            det.lb_retorno,
            det.m3_delta,
            det.observacion
        FROM bal_ruta_pueblo_detalle det
        INNER JOIN bal_balon b ON b.id = det.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
        WHERE det.id_ruta_pueblo = p_id AND det.estado = 1
    ) d;

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

    -- El detalle conserva la conversión original. La nota se deriva de los
    -- valores guardados y no se pierde al editar la observación del usuario.
    SELECT COALESCE(SUM(d.m3_delta), 0) INTO v_m3_exacto
    FROM bal_ruta_pueblo_detalle d
    WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL;
    v_m3_registrado := (v_registro->>'m3_calculado')::NUMERIC;
    v_ajuste_m3 := v_m3_registrado - v_m3_exacto;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro::JSONB
            || jsonb_build_object(
                'm3_calculado_exacto', v_m3_exacto,
                'ajuste_truncamiento_m3', v_ajuste_m3,
                'observacion_truncamiento', CASE WHEN v_ajuste_m3 <> 0 THEN
                    format('Consumo calculado: %s m³. Consumo registrado: %s m³. Ajuste por truncamiento: %s m³.',
                        v_m3_exacto, v_m3_registrado, v_ajuste_m3)
                    ELSE NULL END
            )
            || jsonb_build_object('detalles', v_detalles)
            || jsonb_build_object('detalles_productos', v_detalles_productos)
        )::JSON
    );
END;
$function$;


-- Crea ruta pueblo
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

            IF v_id_balon IS NULL THEN
                RAISE EXCEPTION 'Ítem %: cilindro obligatorio', v_item;
            END IF;

            IF v_lb_salida IS NULL OR v_lb_salida < 0 THEN
                RAISE EXCEPTION 'Ítem %: libras de salida inválidas', v_item;
            END IF;

            IF v_id_balon = ANY (v_balones) THEN
                RAISE EXCEPTION 'El cilindro % está duplicado en la ruta',
                    COALESCE((SELECT NULLIF(TRIM(codigo_balon), '') FROM bal_balon WHERE id = v_id_balon), v_id_balon::TEXT);
            END IF;
            v_balones := array_append(v_balones, v_id_balon);

            SELECT eb.nombre, b.id_almacen, tb.capacidad, tb.capacidad_lb, tb.nombre, b.codigo_balon
            INTO v_estado_balon, v_id_almacen_balon, v_cap_m3, v_cap_lb, v_nombre_tipo, v_codigo_balon
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
            WHERE b.id = v_id_balon AND b.estado = 1;

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

            v_factor_tipo := bal_factor_ruta_balon(v_id_balon);

            IF v_lb_salida > v_cap_lb THEN
                RAISE EXCEPTION
                    'Cilindro %: libras de salida (%) no pueden superar la capacidad lb del tipo "%" (%)',
                    v_balon_label,
                    v_lb_salida,
                    COALESCE(v_nombre_tipo, '(sin tipo)'),
                    v_cap_lb;
            END IF;

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

            IF v_afecta_stock THEN
                SELECT COALESCE(s.stock, 0) INTO v_stock_actual
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen AND s.id_producto = v_id_producto AND s.estado = 1;

                IF COALESCE(v_stock_actual, 0) < v_cantidad_prod THEN
                    RAISE EXCEPTION 'Producto "%" (%): stock insuficiente (% disponible, % requerido)',
                        v_producto_nombre, v_id_producto, COALESCE(v_stock_actual, 0), v_cantidad_prod;
                END IF;
            END IF;
        END LOOP;
    END IF;

    IF NULLIF(p_factor_lb_m3, 0) IS NOT NULL THEN
        v_factor := p_factor_lb_m3;
    ELSE
        SELECT ROUND(AVG(f), 6) INTO v_factor
        FROM unnest(v_factores) AS f;
    END IF;

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


-- Inicia una ruta a pueblo y registra la salida de balones y productos
CREATE OR REPLACE FUNCTION public.bal_iniciar_ruta_pueblo (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
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
    WHERE r.id = p_id AND r.estado = 1
    FOR UPDATE OF r;

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
            format('Salida ruta pueblos #%s · %s lb', p_id, v_det.lb_salida),
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

    FOR v_det_prod IN
        SELECT dp.id_producto, dp.cantidad, p.nombre AS producto_nombre, p.afecta_stock
        FROM bal_ruta_pueblo_detalle_producto dp
        INNER JOIN pro_producto p ON p.id = dp.id_producto
        WHERE dp.id_ruta_pueblo = p_id AND dp.estado = 1
    LOOP
        IF COALESCE(v_det_prod.afecta_stock, FALSE) THEN
            SELECT s.id, COALESCE(s.stock, 0) AS stock, pm.id_unidad_medida AS id_unidad_medida
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
                RAISE EXCEPTION 'Producto "%": stock insuficiente (% disponible, % requerido)',
                    v_det_prod.producto_nombre, v_stock_record.stock, v_det_prod.cantidad;
            END IF;

            v_stock_anterior := v_stock_record.stock;
            v_stock_nuevo := v_stock_anterior - v_det_prod.cantidad;
            v_id_unidad_medida := v_stock_record.id_unidad_medida;

            UPDATE pro_stock
            SET stock = v_stock_nuevo,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_stock_record.id;

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
                format('Salida ruta pueblos #%s · %s ud de %s', p_id, v_det_prod.cantidad, v_det_prod.producto_nombre),
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


-- Registra el retorno de balones y productos de una ruta a pueblo
CREATE OR REPLACE FUNCTION public.bal_registrar_retorno_ruta_pueblo (
  p_id integer,
  p_detalles json DEFAULT '[]'::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_detalles_productos json DEFAULT '[]'::json
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_almacen INTEGER;
    v_factor_ruta NUMERIC;
    v_factor NUMERIC;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_codigo_balon VARCHAR;
    v_balon_label TEXT;
    v_lb_retorno NUMERIC;
    v_id_det INTEGER;
    v_lb_salida NUMERIC;
    v_lb_retorno_existente NUMERIC;
    v_m3_delta NUMERIC;
    v_restante_m3 NUMERIC;
    v_mov JSON;
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
    WHERE r.id = p_id AND r.estado = 1
    FOR UPDATE OF r;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado NOT IN ('EN_RUTA', 'ABIERTA') THEN
        RETURN json_build_object('error', 'Solo se registra retorno en rutas ABIERTA o EN_RUTA', 'registro', NULL);
    END IF;

    IF v_estado = 'ABIERTA' THEN
        v_mov := bal_iniciar_ruta_pueblo(p_id, p_id_usuario_auditoria);
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo iniciar la ruta: %', v_mov->>'error';
        END IF;
        SELECT er.nombre, r.id_almacen, r.factor_lb_m3
        INTO v_estado, v_id_almacen, v_factor_ruta
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id = p_id AND r.estado = 1;
    END IF;

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

            SELECT d.id, d.lb_salida, d.lb_retorno, b.codigo_balon
            INTO v_id_det, v_lb_salida, v_lb_retorno_existente, v_codigo_balon
            FROM bal_ruta_pueblo_detalle d
            LEFT JOIN bal_balon b ON b.id = d.id_balon
            WHERE d.id_ruta_pueblo = p_id
              AND d.id_balon = v_id_balon
              AND d.estado = 1;

            v_balon_label := COALESCE(NULLIF(TRIM(v_codigo_balon), ''), v_id_balon::TEXT);

            IF v_id_det IS NULL THEN
                RAISE EXCEPTION 'Cilindro % no pertenece a esta ruta', v_balon_label;
            END IF;

            IF v_lb_retorno_existente IS NOT NULL THEN
                CONTINUE;
            END IF;

            IF v_lb_retorno > v_lb_salida THEN
                RAISE EXCEPTION 'Cilindro %: lb retorno (%) no puede superar lb salida (%)',
                    v_balon_label, v_lb_retorno, v_lb_salida;
            END IF;

            v_factor := bal_factor_ruta_balon(v_id_balon);

            v_m3_delta := ROUND((v_lb_salida - v_lb_retorno) * v_factor, 4);
            v_restante_m3 := ROUND(v_lb_retorno * v_factor, 4);

            UPDATE bal_ruta_pueblo_detalle
            SET
                lb_retorno = v_lb_retorno,
                m3_delta = v_m3_delta,
                capacidad_restante_m3 = v_restante_m3,
                observacion = COALESCE(
                    NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                    observacion
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_det;

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
                format('Retorno ruta pueblos #%s · %s lb residual', p_id, v_lb_retorno),
                p_id_usuario_auditoria
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el retorno del cilindro %: %',
                    v_balon_label, v_mov->>'error';
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

            IF v_cantidad_retorno_existente IS NOT NULL THEN
                CONTINUE;
            END IF;

            IF v_cantidad_retorno > v_cantidad_enviada THEN
                RAISE EXCEPTION 'Producto %: cantidad retorno (%) no puede superar cantidad enviada (%)',
                    v_producto_nombre, v_cantidad_retorno, v_cantidad_enviada;
            END IF;

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

            IF v_afecta_stock AND v_cantidad_retorno > 0 THEN
                SELECT s.id, COALESCE(s.stock, 0) AS stock, pm.id_unidad_medida AS id_unidad_medida
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
                        format('Retorno ruta pueblos #%s · %s ud de %s', p_id, v_cantidad_retorno, v_producto_nombre),
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
            SELECT TRUNC(COALESCE(SUM(d.m3_delta), 0))
            FROM bal_ruta_pueblo_detalle d
            WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;


-- Cierra una ruta a pueblo comparando m3 calculados y reportados en ventas
CREATE OR REPLACE FUNCTION public.bal_cerrar_ruta_pueblo (
  p_id integer,
  p_m3_reportado_ventas numeric DEFAULT NULL::numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado INTEGER;
    v_m3_calc NUMERIC;
    v_m3_rep NUMERIC;
    v_tolerancia NUMERIC;
    v_descuadre NUMERIC;
    v_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.m3_calculado, r.tolerancia_m3, r.m3_reportado_ventas
    INTO v_estado, v_m3_calc, v_tolerancia, v_m3_rep
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1
    FOR UPDATE OF r;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado = 'CERRADA' THEN
        RETURN bal_obtener_ruta_pueblo(p_id);
    END IF;

    IF v_estado = 'CANCELADA' THEN
        RETURN json_build_object('error', 'No se puede cerrar una ruta cancelada', 'registro', NULL);
    END IF;

    SELECT COUNT(*)::INT INTO v_pendientes
    FROM bal_ruta_pueblo_detalle d
    WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NULL;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error',
            format('Faltan %s cilindro(s) sin libras de retorno', v_pendientes),
            'registro',
            NULL
        );
    END IF;

    -- Truncar una sola vez el total; conservar los decimales de cada cilindro.
    SELECT TRUNC(COALESCE(SUM(d.m3_delta), 0)) INTO v_m3_calc
    FROM bal_ruta_pueblo_detalle d
    WHERE d.id_ruta_pueblo = p_id AND d.estado = 1;

    v_m3_rep := COALESCE(p_m3_reportado_ventas, v_m3_rep);
    IF v_m3_rep IS NULL THEN
        RETURN json_build_object(
            'error',
            'Indica los m³ reportados por el repartidor (ventas de la ruta)',
            'registro',
            NULL
        );
    END IF;

    v_descuadre := ROUND(v_m3_calc - v_m3_rep, 4);

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'CERRADA' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_ruta_pueblo
    SET
        m3_calculado = v_m3_calc,
        m3_reportado_ventas = v_m3_rep,
        descuadre_m3 = v_descuadre,
        id_estado = v_id_estado,
        observacion = CASE
            WHEN p_observacion IS NULL THEN observacion
            ELSE NULLIF(TRIM(p_observacion), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;

COMMIT;
