-- Registra el retorno de balones y productos de una ruta a pueblo
DROP FUNCTION IF EXISTS public.bal_registrar_retorno_ruta_pueblo (
  p_id integer,
  p_detalles json,
  p_id_usuario_auditoria integer,
  p_detalles_productos json
);

CREATE OR REPLACE FUNCTION public.bal_registrar_retorno_ruta_pueblo (
  p_id integer,
  p_detalles json DEFAULT '[]'::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_detalles_productos json DEFAULT '[]'::json
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_manual BOOLEAN;
    v_m3_salida NUMERIC;
    v_m3_retorno NUMERIC;
    v_m3_retorno_existente NUMERIC;
    v_balones INTEGER[] := ARRAY[]::INTEGER[];
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

    SELECT er.nombre, r.id_almacen, r.factor_lb_m3, r.control_gas_manual
    INTO v_estado, v_id_almacen, v_factor_ruta, v_manual
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

    IF v_manual AND COALESCE(json_array_length(p_detalles), 0) = 0
        AND COALESCE(json_array_length(p_detalles_productos), 0) = 0 THEN
        RAISE EXCEPTION 'Registra al menos un retorno antes de guardar';
    END IF;

    IF v_estado = 'ABIERTA' THEN
        v_mov := bal_iniciar_ruta_pueblo(p_id, p_id_usuario_auditoria);
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo iniciar la ruta: %', v_mov->>'error';
        END IF;
        SELECT er.nombre, r.id_almacen, r.factor_lb_m3, r.control_gas_manual
        INTO v_estado, v_id_almacen, v_factor_ruta, v_manual
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

            IF v_id_balon IS NULL OR v_lb_retorno IS NULL OR v_lb_retorno < 0 OR v_lb_retorno::TEXT IN ('NaN', 'Infinity', '-Infinity') THEN
                RAISE EXCEPTION 'Cada ítem requiere idBalon y lbRetorno ≥ 0';
            END IF;

            IF v_id_balon = ANY(v_balones) THEN RAISE EXCEPTION 'Cilindro % repetido en el retorno', v_id_balon; END IF;
            v_balones := array_append(v_balones, v_id_balon);

            SELECT d.id, d.lb_salida, d.lb_retorno, b.codigo_balon, d.m3_salida, d.m3_retorno
            INTO v_id_det, v_lb_salida, v_lb_retorno_existente, v_codigo_balon, v_m3_salida, v_m3_retorno_existente
            FROM bal_ruta_pueblo_detalle d
            LEFT JOIN bal_balon b ON b.id = d.id_balon
            WHERE d.id_ruta_pueblo = p_id
              AND d.id_balon = v_id_balon
              AND d.estado = 1;

            v_balon_label := COALESCE(NULLIF(TRIM(v_codigo_balon), ''), v_id_balon::TEXT);

            IF v_id_det IS NULL THEN
                RAISE EXCEPTION 'Cilindro % no pertenece a esta ruta', v_balon_label;
            END IF;

            v_m3_retorno := COALESCE((v_detalle->>'m3Retorno')::NUMERIC, (v_detalle->>'m3_retorno')::NUMERIC);
            IF v_manual AND (v_m3_retorno IS NULL OR v_m3_retorno < 0
                OR v_m3_retorno::TEXT IN ('NaN', 'Infinity', '-Infinity') OR v_m3_retorno <> ROUND(v_m3_retorno, 4)) THEN
                RAISE EXCEPTION 'Cilindro %: ingresa los m³ de retorno (≥ 0, hasta 4 decimales)', v_balon_label;
            END IF;
            IF v_manual AND v_m3_retorno > v_m3_salida THEN
                RAISE EXCEPTION 'Cilindro %: los m³ de retorno (%) no pueden superar los m³ de salida (%)', v_balon_label, v_m3_retorno, v_m3_salida;
            END IF;
            IF v_lb_retorno_existente IS NOT NULL THEN
                IF v_manual AND (v_m3_retorno IS DISTINCT FROM v_m3_retorno_existente OR v_lb_retorno IS DISTINCT FROM v_lb_retorno_existente) THEN
                    RAISE EXCEPTION 'Cilindro %: el retorno ya fue registrado con otras cantidades', v_balon_label;
                END IF;
                CONTINUE;
            END IF;

            IF v_lb_retorno > v_lb_salida THEN
                RAISE EXCEPTION 'Cilindro %: lb retorno (%) no puede superar lb salida (%)',
                    v_balon_label, v_lb_retorno, v_lb_salida;
            END IF;

            IF v_manual THEN
                v_m3_delta := v_m3_salida - v_m3_retorno;
                v_restante_m3 := v_m3_retorno;
            ELSE
                -- Rutas anteriores: no reingresar gas cuya salida nunca se descontó.
                v_factor := bal_factor_ruta_balon(v_id_balon);
                v_m3_delta := ROUND((v_lb_salida - v_lb_retorno) * v_factor, 4);
                v_restante_m3 := ROUND(v_lb_retorno * v_factor, 4);
            END IF;

            UPDATE bal_ruta_pueblo_detalle
            SET
                lb_retorno = v_lb_retorno,
                m3_retorno = CASE WHEN v_manual THEN v_m3_retorno ELSE NULL END,
                m3_delta = v_m3_delta,
                capacidad_restante_m3 = v_restante_m3,
                observacion = COALESCE(
                    NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                    observacion
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_det;

            IF v_manual THEN PERFORM bal_movimiento_gas_ruta(v_id_det, TRUE, p_id_usuario_auditoria); END IF;

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
            SELECT CASE WHEN v_manual THEN COALESCE(SUM(d.m3_delta), 0) ELSE TRUNC(COALESCE(SUM(d.m3_delta), 0)) END
            FROM bal_ruta_pueblo_detalle d
            WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;
