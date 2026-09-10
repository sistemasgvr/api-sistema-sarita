-- Function: doc_anular_salida
--
-- Anula el ciclo de la OS y libera custodia logística (PENDIENTE_ENVIO /
-- EN_TRANSITO → DISPONIBLE). Si hay reparto vigente, hay que cancelarlo antes.
-- También se invoca en cascada desde ven_eliminar_comprobante (path con
-- id_venta): ese camino no pasa por inv_revertir_por_documento, así que la
-- liberación de balones vive aquí.
DROP FUNCTION IF EXISTS doc_anular_salida(p_id integer, p_motivo character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_anular_salida(p_id integer, p_motivo character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_id_anulada INTEGER;
    v_rev JSON;
    v_id_disponible INTEGER;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o ya fue eliminado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN doc_obtener_salida(p_id);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object(
            'error',
            'El documento fue aceptado por SUNAT; requiere comunicación de baja, no anulación directa',
            'registro', NULL
        );
    END IF;

    -- No anular si hay reparto / actividad operativa todavía vigente.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN (
              'CANCELADA', 'CANCELADO', 'REALIZADA'
          )
    ) THEN
        RETURN json_build_object(
            'error', 'Hay actividad de reparto vigente; cancélala antes de anular la OS',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_disponible
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_disponible IS NULL OR v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados DISPONIBLE, PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    -- Solo se revierte lo que este documento movió por su cuenta.
    IF v_doc.id_venta IS NULL THEN
        v_rev := inv_revertir_por_documento('ORDEN_SALIDA', p_id, p_id_usuario_auditoria);

        IF v_rev->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_rev->>'error';
        END IF;

        UPDATE doc_salida_detalle
        SET id_movimiento = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_doc_salida = p_id;
    END IF;

    -- ------------------------------------------------------------
    -- Custodia logística: PENDIENTE_ENVIO / EN_TRANSITO → DISPONIBLE
    --
    -- Con id_venta el inventario lo movió la venta (no hay movimiento OS),
    -- pero los cilindros sí quedaron comprometidos al crear la OS
    -- (doc_crear_desde_venta). Sin esto quedan atrapados al anular.
    -- Sin id_venta, cubre residuales que no hayan pasado por kardex BALON.
    -- ------------------------------------------------------------
    UPDATE bal_balon b
    SET id_estado_balon = v_id_disponible,
        id_almacen = COALESCE(v_doc.id_almacen, b.id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE b.estado = 1
      AND b.id_estado_balon IN (v_id_pend_envio, v_id_transito)
      AND b.id IN (
          SELECT dd.id_balon
          FROM doc_salida_detalle dd
          WHERE dd.id_doc_salida = p_id
            AND dd.id_balon IS NOT NULL
            AND dd.estado = 1
          UNION
          SELECT vd.id_balon
          FROM ven_comprobante_detalle vd
          WHERE v_doc.id_venta IS NOT NULL
            AND vd.id_comprobante = v_doc.id_venta
            AND vd.id_balon IS NOT NULL
            AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
          UNION
          -- Misma cobertura que doc_crear_desde_venta / doc_obtener_salida
          SELECT pd.id_balon
          FROM bal_prestamo pr
          INNER JOIN bal_prestamo_detalle pd
              ON pd.id_prestamo = pr.id AND pd.estado = 1
          WHERE v_doc.id_venta IS NOT NULL
            AND pr.id_comprobante_venta = v_doc.id_venta
            AND pr.estado = 1
            AND pd.rol = 'ENTREGADO'
            AND pd.id_balon IS NOT NULL
      );

    SELECT lo.id INTO v_id_anulada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'ANULADA' AND lo.estado = 1;

    IF v_id_anulada IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado ANULADA en catalogo EstadoCicloSalida',
            'registro', NULL
        );
    END IF;

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_anulada,
        observaciones = TRIM(BOTH ' ' FROM CONCAT_WS(' | ',
            NULLIF(observaciones, ''),
            'Anulada: ' || COALESCE(NULLIF(TRIM(p_motivo), ''), 'sin motivo indicado'))),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
