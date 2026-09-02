-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.513Z
DROP FUNCTION IF EXISTS bal_actualizar_alquiler_detalle(p_id integer, p_id_balon integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_alquiler_detalle(p_id integer, p_id_balon integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon_actual INTEGER;
    v_fecha_devolucion DATE;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT ad.id_alquiler, ad.id_balon, ad.fecha_devolucion, al.id_cliente, al.id_almacen
    INTO v_id_alquiler, v_id_balon_actual, v_fecha_devolucion, v_id_cliente, v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id AND ad.estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND p_id_balon <> v_id_balon_actual THEN
        IF v_fecha_devolucion IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'No se puede cambiar el cilindro de un detalle ya devuelto',
                'registro', NULL
            );
        END IF;

        IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
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
                'error', 'No se puede alquilar un cilindro dado de baja o reportado como robo',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1 FROM bal_alquiler_detalle
            WHERE id_alquiler = v_id_alquiler AND id_balon = p_id_balon AND id <> p_id AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.id <> p_id
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro ya tiene un alquiler activo sin devolver',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro está prestado actualmente; no se puede alquilar',
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
                'error', 'Faltan estados ALQUILADO / EN_ALMACEN en el catálogo EstadoBalon',
                'registro', NULL
            );
        END IF;

        IF v_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error', 'El alquiler no tiene almacén para devolver el cilindro anterior',
                'registro', NULL
            );
        END IF;

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
            p_fecha                     => NOW(),
            p_id_balon                  => v_id_balon_actual,
            p_cantidad                  => 1,
            p_id_almacen_destino        => v_id_almacen,
            p_id_cliente                => v_id_cliente,
            p_codigo_tipo_documento_origen => 'ALQUILER',
            p_id_documento_origen       => v_id_alquiler,
            p_glosa                     => 'Retorno por cambio de cilindro en alquiler',
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;

        -- inv_registrar_movimiento ya deja el balón devuelto en EN_ALMACEN/v_id_almacen
        -- (mapeo ENTRADA_DEVOLUCION), no hace falta repetirlo aquí.

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'SALIDA_ALQUILER',
            p_fecha                     => NOW(),
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_origen         => v_id_almacen,
            p_id_cliente                => v_id_cliente,
            p_codigo_tipo_documento_origen => 'ALQUILER',
            p_id_documento_origen       => v_id_alquiler,
            p_glosa                     => 'Salida por cambio de cilindro en alquiler',
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;

        -- inv_registrar_movimiento ya deja el balón nuevo en ALQUILADO/v_id_cliente
        -- (mapeo SALIDA_ALQUILER), no hace falta repetirlo aquí.

    END IF;

    UPDATE bal_alquiler_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$
