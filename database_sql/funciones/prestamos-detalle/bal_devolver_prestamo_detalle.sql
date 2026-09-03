-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_devolver_prestamo_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer, p_nombre_estado_contenido character varying, p_observacion character varying);

CREATE OR REPLACE FUNCTION bal_devolver_prestamo_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_nombre_estado_contenido character varying DEFAULT 'VACIO'::character varying, p_observacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_prestamo INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_obs_actual VARCHAR(500);
    v_obs_nueva VARCHAR(500);
    v_retorno JSON;
    v_id_producto_gas INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        pd.observacion,
        p.id_cliente,
        p.id_almacen
    INTO
        v_id_prestamo,
        v_id_balon,
        v_fecha_devolucion,
        v_obs_actual,
        v_id_cliente,
        v_id_almacen
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de préstamo no existe o está inactivo',
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

    SELECT lo.id INTO v_id_estado_detalle_devuelto
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
    LIMIT 1;

    v_obs_nueva := NULLIF(TRIM(p_observacion), '');
    IF v_obs_nueva IS NOT NULL THEN
        IF NULLIF(TRIM(v_obs_actual), '') IS NULL THEN
            v_obs_actual := LEFT(v_obs_nueva, 500);
        ELSE
            v_obs_actual := LEFT(TRIM(v_obs_actual) || ' | ' || v_obs_nueva, 500);
        END IF;
    END IF;

    IF v_id_balon IS NOT NULL THEN
        SELECT b.id_producto_gas INTO v_id_producto_gas
        FROM bal_balon b
        WHERE b.id = v_id_balon AND b.estado = 1;

        v_retorno := bal_prestamo_aplicar_retorno_cilindro(
            v_id_balon,
            v_id_prestamo,
            v_id_cliente,
            v_id_almacen_destino,
            COALESCE(NULLIF(TRIM(p_nombre_estado_contenido), ''), 'VACIO'),
            COALESCE(v_obs_nueva, 'Entrada por devolución de préstamo'),
            p_id_usuario_auditoria,
            TRUE
        );

        IF v_retorno->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_retorno->>'error', 'registro', NULL);
        END IF;
    END IF;

    UPDATE bal_prestamo_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_estado = COALESCE(v_id_estado_detalle_devuelto, id_estado),
        id_producto = COALESCE(v_id_producto_gas, id_producto),
        observacion = COALESCE(v_obs_actual, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    PERFORM bal_prestamo_cerrar_si_completo(
        v_id_prestamo,
        COALESCE(p_fecha_devolucion, CURRENT_DATE),
        p_id_usuario_auditoria
    );

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;
