-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_prestamo_aplicar_salida_cilindro
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.594Z
DROP FUNCTION IF EXISTS bal_prestamo_aplicar_salida_cilindro(p_id_prestamo integer, p_id_balon integer, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_prestamo_aplicar_salida_cilindro(p_id_prestamo integer, p_id_balon integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_comprobante INTEGER;
    v_id_almacen_origen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_prestado INTEGER;
    v_codigo_tipo_comp VARCHAR;
    v_id_documento_ref INTEGER;
    v_codigo_tipo_doc_ref VARCHAR;
    v_mov JSON;
    v_custodia BOOLEAN := FALSE;
BEGIN
    IF p_id_prestamo IS NULL OR p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'Préstamo y cilindro son obligatorios', 'ok', FALSE);
    END IF;

    SELECT p.id_cliente, p.id_comprobante_venta
    INTO v_id_cliente, v_id_comprobante
    FROM bal_prestamo p
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    SELECT b.id_almacen, eb.nombre
    INTO v_id_almacen_origen, v_nombre_estado
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    IF COALESCE(v_nombre_estado, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede prestar un cilindro dado de baja o reportado como robo',
            'ok', FALSE
        );
    END IF;

    IF COALESCE(v_nombre_estado, '') IN (
        'ALQUILADO', 'EN_MANTENIMIENTO', 'EN_RECARGA_EXTERNA', 'POR_RECOGER', 'EN_PODER_CLIENTE'
    ) THEN
        RETURN json_build_object(
            'error',
            format('El cilindro está %s; no se puede prestar', LOWER(REPLACE(v_nombre_estado, '_', ' '))),
            'ok', FALSE
        );
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_prestado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado PRESTADO_CLIENTE del cilindro. Revise el catálogo EstadoBalon.',
            'ok', FALSE
        );
    END IF;

    IF v_id_comprobante IS NOT NULL THEN
        SELECT lo.descripcion INTO v_codigo_tipo_comp
        FROM ven_comprobante c
        INNER JOIN gen_lista_opciones lo ON lo.id = c.id_tipo_comprobante
        WHERE c.id = v_id_comprobante AND c.estado = 1;

        v_id_documento_ref := v_id_comprobante;
        v_codigo_tipo_doc_ref := CASE
            WHEN v_codigo_tipo_comp = '01' THEN 'FACTURA'
            WHEN v_codigo_tipo_comp = '03' THEN 'BOLETA'
            WHEN v_codigo_tipo_comp IN ('NV', 'VSD') THEN 'NOTA_VENTA'
            ELSE 'FACTURA'
        END;
    ELSE
        v_id_documento_ref := p_id_prestamo;
        v_codigo_tipo_doc_ref := 'PRESTAMO';
    END IF;

    v_mov := bal_registrar_salida_documento(
        p_id_balon,
        'SALIDA_PRESTAMO',
        v_id_documento_ref,
        v_codigo_tipo_doc_ref,
        v_id_cliente,
        v_id_almacen_origen,
        'PRESTADO_CLIENTE',
        TRUE,
        NULL,
        COALESCE(NULLIF(TRIM(p_observacion), ''), 'Salida automática por préstamo'),
        p_id_usuario_auditoria
    );

    IF v_mov->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_mov->>'error', 'ok', FALSE);
    END IF;

    IF COALESCE(v_nombre_estado, '') IN ('EN_ALMACEN', '', 'PRESTADO_CLIENTE', 'EN_RUTA_LIMA')
       OR v_nombre_estado IS NULL
    THEN
        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_prestado,
            id_cliente_ubicacion = COALESCE(v_id_cliente, id_cliente_ubicacion),
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    IF COALESCE(v_nombre_estado, '') = 'EN_ALMACEN' THEN
        v_custodia := TRUE;
    END IF;

    RETURN json_build_object('ok', TRUE, 'custodia_actualizada', v_custodia);
END;
$function$
