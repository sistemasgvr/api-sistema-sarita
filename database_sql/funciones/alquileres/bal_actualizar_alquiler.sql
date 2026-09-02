-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_alquiler
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.512Z
DROP FUNCTION IF EXISTS bal_actualizar_alquiler(p_id integer, p_numero_alquiler character varying, p_id_cliente integer, p_id_almacen integer, p_fecha_inicio date, p_fecha_fin_pactada date, p_fecha_fin_real date, p_tarifa_diaria numeric, p_total_cobrado numeric, p_id_estado integer, p_observacion character varying, p_id_comprobante_venta integer, p_id_producto_regulador integer, p_id_producto_stock integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_alquiler(p_id integer, p_numero_alquiler character varying DEFAULT NULL::character varying, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_inicio date DEFAULT NULL::date, p_fecha_fin_pactada date DEFAULT NULL::date, p_fecha_fin_real date DEFAULT NULL::date, p_tarifa_diaria numeric DEFAULT NULL::numeric, p_total_cobrado numeric DEFAULT NULL::numeric, p_id_estado integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_comprobante_venta integer DEFAULT NULL::integer, p_id_producto_regulador integer DEFAULT NULL::integer, p_id_producto_stock integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero VARCHAR;
    v_fin_real_prev DATE;
    v_numero_prev VARCHAR;
    v_almacen_prev INTEGER;
    v_fin_real DATE;
    v_producto_stock INTEGER;
    v_almacen INTEGER;
    v_mov JSON;
    v_stock_reg_ok BOOLEAN;
    v_id_mant_reg INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT al.fecha_fin_real, al.numero_alquiler, al.id_almacen
    INTO v_fin_real_prev, v_numero_prev, v_almacen_prev
    FROM bal_alquiler al
    WHERE al.id = p_id AND al.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    v_numero := NULLIF(TRIM(p_numero_alquiler), '');

    IF v_numero IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_alquiler WHERE LOWER(TRIM(numero_alquiler)) = LOWER(v_numero) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro alquiler con el número ' || v_numero, 'registro', NULL);
    END IF;

    IF p_id_producto_regulador IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM pro_producto
        WHERE id = p_id_producto_regulador
          AND estado = 1
          AND COALESCE(es_alquilable, FALSE) = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El producto debe ser alquilable y estar activo',
            'registro', NULL
        );
    END IF;

    IF p_id_producto_stock IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM pro_producto
        WHERE id = p_id_producto_stock
          AND estado = 1
          AND COALESCE(es_servicio, FALSE) = FALSE
          AND COALESCE(es_gas, FALSE) = FALSE
    ) THEN
        RETURN json_build_object(
            'error', 'El regulador de stock debe ser un accesorio físico activo',
            'registro', NULL
        );
    END IF;

    UPDATE bal_alquiler
    SET
        numero_alquiler = COALESCE(v_numero, numero_alquiler),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        fecha_inicio = COALESCE(p_fecha_inicio, fecha_inicio),
        fecha_fin_pactada = COALESCE(p_fecha_fin_pactada, fecha_fin_pactada),
        fecha_fin_real = COALESCE(p_fecha_fin_real, fecha_fin_real),
        tarifa_diaria = COALESCE(p_tarifa_diaria, tarifa_diaria),
        total_cobrado = COALESCE(p_total_cobrado, total_cobrado),
        id_estado = COALESCE(p_id_estado, id_estado),
        observacion = COALESCE(p_observacion, observacion),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_producto_regulador = COALESCE(p_id_producto_regulador, id_producto_regulador),
        id_producto_stock = COALESCE(p_id_producto_stock, id_producto_stock),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    SELECT
        fecha_fin_real,
        id_producto_stock,
        id_almacen,
        numero_alquiler,
        COALESCE(stock_regulador_reingresado, FALSE),
        id_mantenimiento_regulador
    INTO
        v_fin_real,
        v_producto_stock,
        v_almacen,
        v_numero_prev,
        v_stock_reg_ok,
        v_id_mant_reg
    FROM bal_alquiler
    WHERE id = p_id AND estado = 1;

    -- Reingreso de stock solo si aún no se hizo al devolver el regulador
    -- (BUENO → ya reingresó; PARA_REPARAR → espera fin de mantenimiento)
    IF v_fin_real_prev IS NULL
       AND v_fin_real IS NOT NULL
       AND v_producto_stock IS NOT NULL
       AND NOT COALESCE(v_stock_reg_ok, FALSE)
       AND v_id_mant_reg IS NULL
       AND EXISTS (
           SELECT 1 FROM pro_producto
           WHERE id = v_producto_stock
             AND estado = 1
             AND COALESCE(afecta_stock, FALSE) = TRUE
       )
    THEN
        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'PRODUCTO',
            p_codigo_tipo_movimiento    => 'INGRESO',
            p_fecha                     => v_fin_real,
            p_id_producto               => v_producto_stock,
            p_cantidad                  => 1,
            p_id_almacen_origen         => v_almacen,
            p_codigo_tipo_documento_origen => 'ALQUILER',
            p_id_documento_origen       => p_id,
            p_glosa                     => 'Devolución por fin de alquiler ' || v_numero_prev,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_alquiler(p_id);
END;
$function$
