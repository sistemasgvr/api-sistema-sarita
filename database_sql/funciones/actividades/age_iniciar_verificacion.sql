-- Function: age_iniciar_verificacion
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql

DROP FUNCTION IF EXISTS age_iniciar_verificacion(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_verificacion(
    p_id_actividad integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act RECORD;
    v_id_pendiente INTEGER;
    v_items INTEGER := 0;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_prestamo, a.id_alquiler, a.id_doc_salida, a.id_comprobante,
           a.id_trabajador_responsable
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id_actividad AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM age_actividad_item i
        WHERE i.id_actividad = p_id_actividad AND i.estado = 1
    ) THEN
        RETURN age_obtener_actividad(p_id_actividad);
    END IF;

    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de iniciar la verificacion',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NOT NULL THEN
        DECLARE
            v_id_trabajador_sesion INTEGER;
        BEGIN
            SELECT u.id_trabajador INTO v_id_trabajador_sesion
            FROM auth_usuarios u
            WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

            IF v_id_trabajador_sesion IS NULL
               OR v_id_trabajador_sesion IS DISTINCT FROM v_act.id_trabajador_responsable THEN
                RETURN json_build_object(
                    'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar la verificacion',
                    'registro', NULL
                );
            END IF;
        END;
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_act.id_prestamo IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY pd.id),
            COALESCE(pd.id_producto, b.id_producto_gas),
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            pd.id_balon,
            pd.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_prestamo_detalle pd
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.id_prestamo = v_act.id_prestamo
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND pd.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;
    ELSIF v_act.id_alquiler IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_alquiler_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY ad.id),
            b.id_producto_gas,
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            ad.id_balon,
            ad.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_alquiler_detalle ad
        LEFT JOIN bal_balon b ON b.id = ad.id_balon
        WHERE ad.id_alquiler = v_act.id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL
          AND ad.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;

        -- Regulador pendiente: fila sin balon, solo producto.
        IF EXISTS (
            SELECT 1 FROM bal_alquiler a
            WHERE a.id = v_act.id_alquiler
              AND a.id_producto_regulador IS NOT NULL
              AND a.fecha_devolucion_regulador IS NULL
        ) THEN
            SELECT COALESCE(MAX(item), 0) INTO v_n
            FROM age_actividad_item
            WHERE id_actividad = p_id_actividad AND estado = 1;

            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_estado_verificacion_salida, id_estado_verificacion_llegada,
                id_usuario_creacion, id_usuario_modificacion
            )
            SELECT
                p_id_actividad,
                v_n + 1,
                a.id_producto_regulador,
                COALESCE(pr.nombre, 'Regulador / accesorio'),
                1,
                NULL,
                v_id_pendiente,
                v_id_pendiente,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            FROM bal_alquiler a
            LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
            WHERE a.id = v_act.id_alquiler;

            v_items := v_items + 1;
        END IF;
    ELSIF v_act.id_doc_salida IS NOT NULL OR v_act.id_comprobante IS NOT NULL THEN
        -- REPARTO sin items materializados: no hay nada que derivar aqui, los
        -- items los crea age_crear_actividad desde el detalle del documento.
        RETURN json_build_object(
            'error', 'La actividad de reparto no tiene items: revisa el documento de origen',
            'registro', NULL
        );
    ELSE
        RETURN json_build_object(
            'error', 'La actividad no tiene origen del que derivar items',
            'registro', NULL
        );
    END IF;

    RETURN age_obtener_actividad(p_id_actividad);
END;
$function$;
