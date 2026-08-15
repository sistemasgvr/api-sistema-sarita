CREATE OR REPLACE FUNCTION bal_actualizar_recarga_planta(
    p_id INTEGER,
    p_fecha_salida DATE DEFAULT NULL,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_guia_retorno INTEGER DEFAULT NULL,
    p_serie_guia_ingreso VARCHAR DEFAULT NULL,
    p_numero_guia_ingreso VARCHAR DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_serie_factura VARCHAR DEFAULT NULL,
    p_numero_factura VARCHAR DEFAULT NULL,
    p_fecha_llegada_almacen DATE DEFAULT NULL,
    p_lote VARCHAR DEFAULT NULL,
    p_fecha_vencimiento_lote DATE DEFAULT NULL,
    p_fecha_prueba_hidrostatica DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_actual VARCHAR;
    v_id_estado INTEGER;
    v_det RECORD;
    v_upd JSON;
    v_fecha_llegada DATE;
    v_id_compra INTEGER;
    v_lote VARCHAR;
    v_fecha_venc_lote DATE;
    v_fecha_ph DATE;
    v_serie_factura VARCHAR;
    v_numero_factura VARCHAR;
    v_id_tipo_doc_compra INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_entrada_llenado INTEGER;
    v_id_tipo_entrada_planta INTEGER;
    v_id_almacen_orden INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_recarga_planta WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'Orden de recarga no encontrada', 'registro', NULL);
    END IF;

    SELECT est.nombre
    INTO v_estado_actual
    FROM bal_recarga_planta rp
    LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
    WHERE rp.id = p_id;

    IF p_id_guia_retorno IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gre_guia_remision WHERE id = p_id_guia_retorno AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La guía de retorno no existe', 'registro', NULL);
    END IF;

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de compra no existe', 'registro', NULL);
    END IF;

    -- Si se vincula compra, completar serie/número factura desde el comprobante cuando no vienen.
    v_serie_factura := NULLIF(TRIM(p_serie_factura), '');
    v_numero_factura := NULLIF(TRIM(p_numero_factura), '');
    IF p_id_comprobante_compra IS NOT NULL AND (v_serie_factura IS NULL OR v_numero_factura IS NULL) THEN
        SELECT
            COALESCE(v_serie_factura, NULLIF(TRIM(c.serie), '')),
            COALESCE(v_numero_factura, NULLIF(TRIM(c.numero), ''))
        INTO v_serie_factura, v_numero_factura
        FROM com_comprobante_compra c
        WHERE c.id = p_id_comprobante_compra AND c.estado = 1;
    END IF;

    UPDATE bal_recarga_planta
    SET
        fecha_salida = COALESCE(p_fecha_salida, fecha_salida),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_guia_retorno = COALESCE(p_id_guia_retorno, id_guia_retorno),
        -- '' explícito limpia; NULL conserva.
        serie_guia_ingreso = CASE
            WHEN p_serie_guia_ingreso IS NOT NULL THEN NULLIF(TRIM(p_serie_guia_ingreso), '')
            ELSE serie_guia_ingreso
        END,
        numero_guia_ingreso = CASE
            WHEN p_numero_guia_ingreso IS NOT NULL THEN NULLIF(TRIM(p_numero_guia_ingreso), '')
            ELSE numero_guia_ingreso
        END,
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        serie_factura = CASE
            WHEN p_id_comprobante_compra IS NOT NULL AND v_serie_factura IS NOT NULL THEN v_serie_factura
            WHEN p_serie_factura IS NOT NULL THEN NULLIF(TRIM(p_serie_factura), '')
            ELSE serie_factura
        END,
        numero_factura = CASE
            WHEN p_id_comprobante_compra IS NOT NULL AND v_numero_factura IS NOT NULL THEN v_numero_factura
            WHEN p_numero_factura IS NOT NULL THEN NULLIF(TRIM(p_numero_factura), '')
            ELSE numero_factura
        END,
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = CASE
            WHEN p_lote IS NOT NULL THEN NULLIF(TRIM(p_lote), '')
            ELSE lote
        END,
        fecha_vencimiento_lote = CASE
            WHEN p_fecha_vencimiento_lote IS NOT NULL THEN p_fecha_vencimiento_lote
            ELSE fecha_vencimiento_lote
        END,
        fecha_prueba_hidrostatica = CASE
            WHEN p_fecha_prueba_hidrostatica IS NOT NULL THEN p_fecha_prueba_hidrostatica
            ELSE fecha_prueba_hidrostatica
        END,
        observacion = CASE
            WHEN p_observacion IS NOT NULL THEN NULLIF(TRIM(p_observacion), '')
            ELSE observacion
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    -- Propagar protocolo/retorno a detalle + movimiento (también si solo corrigen lote en CERRADO).
    IF p_fecha_llegada_almacen IS NOT NULL
       OR p_lote IS NOT NULL
       OR p_fecha_vencimiento_lote IS NOT NULL
       OR p_fecha_prueba_hidrostatica IS NOT NULL
       OR p_id_comprobante_compra IS NOT NULL
       OR p_serie_guia_ingreso IS NOT NULL
       OR p_serie_factura IS NOT NULL
       OR p_numero_factura IS NOT NULL
    THEN
        SELECT
            fecha_llegada_almacen,
            NULLIF(TRIM(lote), ''),
            fecha_vencimiento_lote,
            fecha_prueba_hidrostatica,
            NULLIF(TRIM(serie_factura), ''),
            NULLIF(TRIM(numero_factura), ''),
            id_comprobante_compra,
            id_almacen
        INTO
            v_fecha_llegada,
            v_lote,
            v_fecha_venc_lote,
            v_fecha_ph,
            v_serie_factura,
            v_numero_factura,
            v_id_compra,
            v_id_almacen_orden
        FROM bal_recarga_planta
        WHERE id = p_id;

        FOR v_det IN
            SELECT d.id_movimiento_recarga, d.id, d.id_producto, d.capacidad, d.id_unidad_medida
            FROM bal_recarga_planta_detalle d
            WHERE d.id_recarga_planta = p_id
              AND d.estado = 1
              AND d.id_movimiento_recarga IS NOT NULL
        LOOP
            UPDATE bal_recarga_planta_detalle
            SET
                lote = v_lote,
                fecha_vencimiento_lote = v_fecha_venc_lote,
                fecha_prueba_hidrostatica = v_fecha_ph,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id;

            v_upd := bal_actualizar_movimiento_recarga(
                v_det.id_movimiento_recarga,
                NULL,
                v_det.id_producto,
                v_det.capacidad,
                v_det.id_unidad_medida,
                NULL,
                NULL,
                NULLIF(TRIM(COALESCE(p_serie_guia_ingreso, '')), ''),
                NULLIF(TRIM(COALESCE(p_numero_guia_ingreso, '')), ''),
                v_serie_factura,
                v_numero_factura,
                NULL,
                CASE WHEN p_fecha_llegada_almacen IS NOT NULL THEN p_fecha_llegada_almacen ELSE NULL END,
                COALESCE(v_lote, ''),
                v_fecha_venc_lote,
                v_fecha_ph,
                NULL,
                NULL,
                COALESCE(p_id_almacen, v_id_almacen_orden),
                COALESCE(p_id_comprobante_compra, v_id_compra),
                p_id_usuario_auditoria
            );

            IF v_upd->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_upd->>'error', 'registro', NULL);
            END IF;
            -- P.H. → historial del balón: lo hace bal_actualizar_movimiento_recarga (idempotente).
        END LOOP;
    END IF;

    -- Si se vincula compra, los movimientos de entrada del kardex deben apuntar a COMPRA.
    IF p_id_comprobante_compra IS NOT NULL THEN
        SELECT lo.id INTO v_id_tipo_doc_compra
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_doc_recarga
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_entrada_llenado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_LLENADO' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_entrada_planta
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA' AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_doc_compra IS NOT NULL AND v_id_tipo_doc_recarga IS NOT NULL THEN
            IF v_id_tipo_entrada_llenado IS NOT NULL THEN
                UPDATE bal_movimiento m
                SET
                    id_documento_ref = p_id_comprobante_compra,
                    id_tipo_documento_ref = v_id_tipo_doc_compra,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE m.estado = 1
                  AND m.id_tipo_movimiento = v_id_tipo_entrada_llenado
                  AND m.id_tipo_documento_ref = v_id_tipo_doc_recarga
                  AND m.id_documento_ref = p_id;
            END IF;

            IF v_id_tipo_entrada_planta IS NOT NULL THEN
                UPDATE bal_movimiento m
                SET
                    id_documento_ref = p_id_comprobante_compra,
                    id_tipo_documento_ref = v_id_tipo_doc_compra,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE m.estado = 1
                  AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
                  AND m.id_tipo_documento_ref = v_id_tipo_doc_recarga
                  AND m.id_documento_ref IN (
                      SELECT d.id_movimiento_recarga
                      FROM bal_recarga_planta_detalle d
                      WHERE d.id_recarga_planta = p_id
                        AND d.estado = 1
                        AND d.id_movimiento_recarga IS NOT NULL
                  );
            END IF;
        END IF;
    END IF;

    -- Protocolo planta al retorno (o corrección en órdenes ya retornadas/cerradas).
    SELECT
        fecha_llegada_almacen,
        id_comprobante_compra,
        NULLIF(TRIM(lote), ''),
        fecha_vencimiento_lote,
        fecha_prueba_hidrostatica
    INTO v_fecha_llegada, v_id_compra, v_lote, v_fecha_venc_lote, v_fecha_ph
    FROM bal_recarga_planta
    WHERE id = p_id;

    IF v_fecha_llegada IS NOT NULL THEN
        IF v_lote IS NULL THEN
            RETURN json_build_object(
                'error',
                'El número de lote es obligatorio al registrar el retorno (protocolo de planta)',
                'registro',
                NULL
            );
        END IF;

        IF v_fecha_venc_lote IS NULL THEN
            RETURN json_build_object(
                'error',
                'La fecha de vencimiento del lote es obligatoria al registrar el retorno',
                'registro',
                NULL
            );
        END IF;

        IF v_fecha_ph IS NULL THEN
            RETURN json_build_object(
                'error',
                'La fecha de prueba hidrostática (P.H.) es obligatoria al registrar el retorno',
                'registro',
                NULL
            );
        END IF;
    END IF;

    -- CERRADO solo con compra + retorno físico. Solo llegada → RETORNADO.
    IF v_id_compra IS NOT NULL AND v_fecha_llegada IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'CERRADO' AND lo.estado = 1
        LIMIT 1;
    ELSIF v_fecha_llegada IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'RETORNADO' AND lo.estado = 1
        LIMIT 1;
    ELSE
        v_id_estado := NULL;
    END IF;

    IF v_id_estado IS NOT NULL THEN
        UPDATE bal_recarga_planta
        SET id_estado = v_id_estado
        WHERE id = p_id;
    END IF;

    RETURN bal_obtener_recarga_planta(p_id);
END;
$function$;
