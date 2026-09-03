-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.529Z
DROP FUNCTION IF EXISTS bal_crear_alquiler_detalle(p_id_alquiler integer, p_id_balon integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_alquiler_detalle(p_id_alquiler integer, p_id_balon integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_id_estado_alquilado INTEGER;
    v_mov_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El alquiler indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = p_id_balon
          AND COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
    ) THEN
        RETURN json_build_object(
            'error',
            'No se puede alquilar un cilindro dado de baja o reportado como robo',
            'registro',
            NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler_detalle
        WHERE id_alquiler = p_id_alquiler AND id_balon = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_alquiler_detalle ad
        INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
        WHERE ad.id_balon = p_id_balon
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL
    ) THEN
        RETURN json_build_object(
            'error',
            'El cilindro ya tiene un alquiler activo sin devolver',
            'registro',
            NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        WHERE pd.id_balon = p_id_balon
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
    ) THEN
        RETURN json_build_object(
            'error',
            'El cilindro está prestado actualmente; no se puede alquilar',
            'registro',
            NULL
        );
    END IF;

    SELECT id_cliente, id_almacen
    INTO v_id_cliente, v_id_almacen
    FROM bal_alquiler
    WHERE id = p_id_alquiler AND estado = 1;

    SELECT lo.id INTO v_id_estado_alquilado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_alquilado IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado ALQUILADO del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    INSERT INTO bal_alquiler_detalle (
        id_alquiler, id_balon,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_alquiler, p_id_balon,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_mov_result := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'SALIDA_ALQUILER',
        p_fecha                     => LOCALTIMESTAMP,
        p_id_balon                  => p_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_origen         => v_id_almacen,
        p_id_cliente                => v_id_cliente,
        p_codigo_tipo_documento_origen => 'ALQUILER',
        p_id_documento_origen       => p_id_alquiler,
        p_glosa                     => 'Salida por alquiler',
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );

    IF v_mov_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_mov_result->>'error';
    END IF;

    -- En cliente no sabemos si consume el gas → contenido DESCONOCIDO.
    UPDATE bal_balon
    SET
        id_cliente_ubicacion = v_id_cliente,
        id_almacen = NULL,
        id_estado_balon = v_id_estado_alquilado,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN bal_obtener_alquiler_detalle(v_id);
END;
$function$
