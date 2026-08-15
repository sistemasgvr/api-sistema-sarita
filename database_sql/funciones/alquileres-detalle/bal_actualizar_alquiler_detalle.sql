CREATE OR REPLACE FUNCTION bal_actualizar_alquiler_detalle(
    p_id INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon_actual INTEGER;
    v_fecha_devolucion DATE;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_id_tipo_salida INTEGER;
    v_id_tipo_entrada INTEGER;
    v_id_tipo_doc INTEGER;
    v_id_estado_alquilado INTEGER;
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

        SELECT lo.id INTO v_id_tipo_salida
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_ALQUILER' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_entrada
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ALQUILER' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_alquilado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_alquilado IS NULL OR v_id_estado_en_almacen IS NULL THEN
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

        IF v_id_tipo_entrada IS NOT NULL THEN
            v_mov := bal_crear_movimiento(
                v_id_balon_actual,
                v_id_tipo_entrada,
                v_id_alquiler,
                v_id_tipo_doc,
                v_id_cliente,
                NULL::INTEGER,
                v_id_almacen,
                NOW()::TIMESTAMP,
                'Retorno por cambio de cilindro en alquiler'::VARCHAR,
                p_id_usuario_auditoria
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;
        END IF;

        UPDATE bal_balon
        SET
            id_cliente_ubicacion = NULL,
            id_almacen = v_id_almacen,
            id_estado_balon = v_id_estado_en_almacen,
            id_estado_contenido = COALESCE(bal_id_estado_contenido('VACIO'), id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon_actual AND estado = 1;

        IF v_id_tipo_salida IS NOT NULL THEN
            v_mov := bal_crear_movimiento(
                p_id_balon,
                v_id_tipo_salida,
                v_id_alquiler,
                v_id_tipo_doc,
                v_id_cliente,
                v_id_almacen,
                NULL::INTEGER,
                NOW()::TIMESTAMP,
                'Salida por cambio de cilindro en alquiler'::VARCHAR,
                p_id_usuario_auditoria
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;
        END IF;

        UPDATE bal_balon
        SET
            id_cliente_ubicacion = v_id_cliente,
            id_almacen = NULL,
            id_estado_balon = v_id_estado_alquilado,
            id_estado_contenido = COALESCE(bal_id_estado_contenido('DESCONOCIDO'), id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;

        PERFORM bal_sync_capacidad_restante(
            p_id_balon, NULL, NULL, NULL, 'CLEAR', NULL, p_id_usuario_auditoria
        );
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
$function$;
