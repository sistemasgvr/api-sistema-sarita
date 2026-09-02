-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_prestamo_aplicar_retorno_cilindro
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.593Z
DROP FUNCTION IF EXISTS bal_prestamo_aplicar_retorno_cilindro(p_id_balon integer, p_id_prestamo integer, p_id_cliente integer, p_id_almacen_destino integer, p_nombre_contenido character varying, p_observacion character varying, p_id_usuario_auditoria integer, p_crear_movimiento boolean);

CREATE OR REPLACE FUNCTION bal_prestamo_aplicar_retorno_cilindro(p_id_balon integer, p_id_prestamo integer, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen_destino integer DEFAULT NULL::integer, p_nombre_contenido character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_crear_movimiento boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
    v_id_almacen INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_contenido VARCHAR;
    v_capacidad NUMERIC;
    v_mov JSON;
    v_en_campo BOOLEAN := FALSE;
BEGIN
    IF p_id_balon IS NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    SELECT eb.nombre, b.id_almacen, tb.capacidad
    INTO v_nombre_estado, v_id_almacen, v_capacidad
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    v_en_campo := COALESCE(v_nombre_estado, '') IN (
        'PRESTADO_CLIENTE', 'POR_RECOGER', 'EN_PODER_CLIENTE', 'EN_RUTA_LIMA'
    ) OR (COALESCE(v_nombre_estado, '') = 'EN_ALMACEN' AND v_id_almacen IS NULL);

    -- Ya está en almacén (p. ej. volvió por otro flujo): no pisar contenido/stock.
    IF COALESCE(v_nombre_estado, '') = 'EN_ALMACEN' AND v_id_almacen IS NOT NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    -- Custodia de otro proceso (alquiler / recarga / taller): solo se cierra el préstamo.
    IF COALESCE(v_nombre_estado, '') IN (
        'ALQUILADO', 'EN_MANTENIMIENTO', 'EN_RECARGA_EXTERNA', 'DADO_DE_BAJA', 'ROBO'
    ) THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    IF NOT v_en_campo AND COALESCE(v_nombre_estado, '') <> '' THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    IF p_id_almacen_destino IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el almacén de destino de la devolución', 'ok', FALSE);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'ok', FALSE);
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado EN_ALMACEN del cilindro. Revise el catálogo EstadoBalon.',
            'ok', FALSE
        );
    END IF;

    IF p_crear_movimiento THEN
        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
            p_fecha                     => NOW(),
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_destino        => p_id_almacen_destino,
            p_id_cliente                => p_id_cliente,
            p_codigo_tipo_documento_origen => 'PRESTAMO',
            p_id_documento_origen       => p_id_prestamo,
            p_glosa                     => COALESCE(NULLIF(TRIM(p_observacion), ''), 'Entrada por devolución de préstamo'),
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'ok', FALSE);
        END IF;
    END IF;

    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = p_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN json_build_object('ok', TRUE, 'skipped', FALSE);
END;
$function$
