-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.540Z
DROP FUNCTION IF EXISTS bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_finalizado INTEGER;
    v_mov_result JSON;
    v_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_alquiler,
        ad.id_balon,
        ad.fecha_devolucion,
        al.id_cliente,
        al.id_almacen
    INTO
        v_id_alquiler,
        v_id_balon,
        v_fecha_devolucion,
        v_id_cliente,
        v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de alquiler no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    IF v_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el almacén de destino de la devolución',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacén de destino no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado EN_ALMACEN del cilindro. Revise el catálogo EstadoBalon.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_alquiler_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    v_mov_result := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
        p_fecha                     => NOW(),
        p_id_balon                  => v_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_destino        => v_id_almacen_destino,
        p_id_cliente                => v_id_cliente,
        p_codigo_tipo_documento_origen => 'ALQUILER',
        p_id_documento_origen       => v_id_alquiler,
        p_glosa                     => 'Entrada por devolución de alquiler',
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );

    IF v_mov_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_mov_result->>'error';
    END IF;

    -- Custodia: vuelve a almacén. Contenido: se asume vacío (envase usado que regresa).
    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = v_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_id_balon
      AND estado = 1;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_alquiler_detalle
    WHERE id_alquiler = v_id_alquiler
      AND estado = 1
      AND fecha_devolucion IS NULL;

    -- No cerrar si aún falta devolver el regulador/accesorio
    IF v_pendientes = 0
       AND NOT EXISTS (
           SELECT 1
           FROM bal_alquiler a
           WHERE a.id = v_id_alquiler
             AND a.estado = 1
             AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
             AND a.fecha_devolucion_regulador IS NULL
       )
    THEN
        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, COALESCE(p_fecha_devolucion, CURRENT_DATE)),
            id_estado = COALESCE(v_id_estado_finalizado, id_estado),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_alquiler
          AND estado = 1;
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$
