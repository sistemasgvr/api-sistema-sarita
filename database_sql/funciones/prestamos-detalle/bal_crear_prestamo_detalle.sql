-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
DROP FUNCTION IF EXISTS bal_crear_prestamo_detalle(p_id_prestamo integer, p_id_balon integer, p_id_producto integer, p_motivo_especifico character varying, p_fecha_entregado date, p_fecha_prestamo date, p_dias_prestamo integer, p_fecha_vencimiento date, p_fecha_devolucion date, p_serie_guia_entrega character varying, p_numero_guia_entrega character varying, p_serie_guia_devolucion character varying, p_numero_guia_devolucion character varying, p_id_estado integer, p_observacion character varying, p_id_usuario_auditoria integer, p_id_guia_entrega integer, p_id_guia_devolucion integer);

CREATE OR REPLACE FUNCTION bal_crear_prestamo_detalle(p_id_prestamo integer, p_id_balon integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_motivo_especifico character varying DEFAULT NULL::character varying, p_fecha_entregado date DEFAULT NULL::date, p_fecha_prestamo date DEFAULT NULL::date, p_dias_prestamo integer DEFAULT 30, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_devolucion date DEFAULT NULL::date, p_serie_guia_entrega character varying DEFAULT NULL::character varying, p_numero_guia_entrega character varying DEFAULT NULL::character varying, p_serie_guia_devolucion character varying DEFAULT NULL::character varying, p_numero_guia_devolucion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_guia_entrega integer DEFAULT NULL::integer, p_id_guia_devolucion integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_producto INTEGER;
    v_id_estado_detalle INTEGER;
    v_salida JSON;
    v_serie_entrega VARCHAR;
    v_numero_entrega VARCHAR;
    v_serie_devolucion VARCHAR;
    v_numero_devolucion VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_id_producto := p_id_producto;
    v_id_estado_detalle := p_id_estado;
    v_serie_entrega := p_serie_guia_entrega;
    v_numero_entrega := p_numero_guia_entrega;
    v_serie_devolucion := p_serie_guia_devolucion;
    v_numero_devolucion := p_numero_guia_devolucion;

    -- Serie/número quedan como snapshot de la GRE vinculada (compatibilidad UI).
    IF p_id_guia_entrega IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_entrega, v_numero_entrega
        FROM doc_salida g
        WHERE g.id = p_id_guia_entrega AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de entrega indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF p_id_guia_devolucion IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_devolucion, v_numero_devolucion
        FROM doc_salida g
        WHERE g.id = p_id_guia_devolucion AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de devolución indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF v_id_estado_detalle IS NULL AND p_fecha_devolucion IS NULL THEN
        SELECT lo.id INTO v_id_estado_detalle
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    IF p_id_balon IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(b.id_producto_gas, v_id_producto) INTO v_id_producto
        FROM bal_balon b
        WHERE b.id = p_id_balon AND b.estado = 1;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro está alquilado actualmente; no se puede prestar',
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
                'error', 'El cilindro ya tiene un préstamo activo sin devolver',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_prestamo_detalle (
        id_prestamo, id_balon, id_producto, motivo_especifico,
        fecha_entregado, fecha_prestamo, dias_prestamo, fecha_vencimiento, fecha_devolucion,
        id_doc_salida_entrega, id_guia_devolucion,
        serie_guia_entrega, numero_guia_entrega, serie_guia_devolucion, numero_guia_devolucion,
        id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_prestamo, p_id_balon, v_id_producto, p_motivo_especifico,
        p_fecha_entregado, p_fecha_prestamo, COALESCE(p_dias_prestamo, 30), p_fecha_vencimiento, p_fecha_devolucion,
        p_id_guia_entrega, p_id_guia_devolucion,
        v_serie_entrega, v_numero_entrega, v_serie_devolucion, v_numero_devolucion,
        v_id_estado_detalle, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Histórico ya devuelto: no mueve custodia. Activo: sale del almacén.
    IF p_id_balon IS NOT NULL AND p_fecha_devolucion IS NULL THEN
        v_salida := bal_prestamo_aplicar_salida_cilindro(
            p_id_prestamo,
            p_id_balon,
            p_observacion,
            p_id_usuario_auditoria
        );

        IF v_salida->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_salida->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_prestamo_detalle(v_id);
END;
$function$;
