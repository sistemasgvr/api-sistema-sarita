CREATE OR REPLACE FUNCTION bal_devolver_regulador_alquiler(
    p_id_alquiler INTEGER,
    p_fecha DATE DEFAULT CURRENT_DATE,
    p_condicion VARCHAR DEFAULT 'BUENO',
    p_observacion VARCHAR DEFAULT NULL,
    p_id_recojo INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_producto INTEGER;
    v_almacen INTEGER;
    v_numero VARCHAR;
    v_condicion VARCHAR := UPPER(TRIM(COALESCE(p_condicion, '')));
    v_id_condicion INTEGER;
    v_id_tipo_rep INTEGER;
    v_id_estado_pend INTEGER;
    v_id_mant INTEGER;
    v_mov JSON;
    v_obs VARCHAR(500);
    v_ya_devuelto DATE;
    v_stock_ok BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_alquiler IS NULL THEN
        RETURN json_build_object('error', 'El alquiler es obligatorio', 'registro', NULL);
    END IF;

    IF v_condicion NOT IN ('BUENO', 'PARA_REPARAR') THEN
        RETURN json_build_object(
            'error', 'La condición del regulador debe ser BUENO o PARA_REPARAR',
            'registro', NULL
        );
    END IF;

    SELECT
        COALESCE(a.id_producto_stock, a.id_producto_regulador),
        a.id_almacen,
        a.numero_alquiler,
        a.fecha_devolucion_regulador,
        COALESCE(a.stock_regulador_reingresado, FALSE)
    INTO v_producto, v_almacen, v_numero, v_ya_devuelto, v_stock_ok
    FROM bal_alquiler a
    WHERE a.id = p_id_alquiler AND a.estado = 1;

    IF v_producto IS NULL THEN
        RETURN json_build_object(
            'error', 'El alquiler no tiene regulador/accesorio asociado',
            'registro', NULL
        );
    END IF;

    IF v_ya_devuelto IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object(
                'id_alquiler', p_id_alquiler,
                'ya_devuelto', TRUE,
                'fecha_devolucion_regulador', v_ya_devuelto
            )
        );
    END IF;

    SELECT lo.id INTO v_id_condicion
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'CondicionRegulador' AND lo.nombre = v_condicion AND lo.estado = 1
    LIMIT 1;

    IF v_id_condicion IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró la condición ' || v_condicion || ' en CondicionRegulador',
            'registro', NULL
        );
    END IF;

    v_obs := NULLIF(TRIM(COALESCE(p_observacion, '')), '');

    UPDATE bal_alquiler
    SET
        fecha_devolucion_regulador = COALESCE(p_fecha, CURRENT_DATE),
        id_condicion_regulador = v_id_condicion,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_alquiler AND estado = 1;

    IF v_condicion = 'BUENO' THEN
        IF NOT v_stock_ok
           AND v_almacen IS NOT NULL
           AND EXISTS (
               SELECT 1 FROM pro_producto
               WHERE id = v_producto
                 AND estado = 1
                 AND COALESCE(afecta_stock, FALSE) = TRUE
           )
        THEN
            v_mov := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => COALESCE(p_fecha, CURRENT_DATE),
                p_id_producto               => v_producto,
                p_cantidad                  => 1,
                p_id_almacen_origen         => v_almacen,
                p_codigo_tipo_documento_origen => 'ALQUILER',
                p_id_documento_origen       => p_id_alquiler,
                p_glosa                     => 'Reingreso regulador OK — alquiler ' || COALESCE(v_numero, '#' || p_id_alquiler),
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
            END IF;

            UPDATE bal_alquiler
            SET
                stock_regulador_reingresado = TRUE,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = p_id_alquiler AND estado = 1;
        END IF;
    ELSE
        -- PARA_REPARAR: crear mantenimiento de producto (sin reingresar a stock aún)
        SELECT lo.id INTO v_id_tipo_rep
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMantenimiento' AND lo.nombre = 'REPARACION' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_pend
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_pend IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontró el estado PENDIENTE de mantenimiento',
                'registro', NULL
            );
        END IF;

        INSERT INTO bal_mantenimiento (
            id_balon,
            id_producto,
            id_almacen,
            id_alquiler,
            id_recojo,
            id_tipo_mantenimiento,
            fecha_ingreso,
            descripcion,
            costo,
            es_externo,
            id_estado,
            observacion,
            id_usuario_creacion,
            id_usuario_modificacion
        )
        VALUES (
            NULL,
            v_producto,
            v_almacen,
            p_id_alquiler,
            p_id_recojo,
            v_id_tipo_rep,
            COALESCE(p_fecha, CURRENT_DATE),
            'Reparación de regulador/accesorio devuelto del alquiler '
                || COALESCE(v_numero, '#' || p_id_alquiler),
            0,
            FALSE,
            v_id_estado_pend,
            v_obs,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_mant;

        UPDATE bal_alquiler
        SET
            id_mantenimiento_regulador = v_id_mant,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_alquiler AND estado = 1;
    END IF;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'id_alquiler', p_id_alquiler,
            'condicion', v_condicion,
            'id_mantenimiento', v_id_mant,
            'stock_reingresado', v_condicion = 'BUENO'
        )
    );
END;
$function$;
