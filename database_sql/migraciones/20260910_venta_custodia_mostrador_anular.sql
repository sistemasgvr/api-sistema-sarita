-- ============================================================
-- Migración: custodia del cilindro en venta de mostrador y bloqueo de
--            anulación tras la entrega
-- Fecha: 2026-09-10
--
-- Dos decisiones de producto sobre qué pasa con el envase después de vender:
--
-- 1) Entregado = no se anula.
--    ven_crear_comprobante descuenta stock y doc_anular_salida /
--    ven_eliminar_comprobante lo reponen al anular. Eso vale mientras el
--    cilindro siga en local, pero una vez que el reparto se culmina
--    (age_culminar_entrega) el envase está EN_PODER_CLIENTE: reponerlo al
--    stock vendible inventa mercadería que no tenemos y el cilindro queda
--    ofertable en el POS estando en casa del cliente. Con un REPARTO en
--    estado REALIZADA la anulación pasa a ser un error duro, tanto por la OS
--    como por la venta. La corrección documental correcta es la nota de
--    crédito (que además registra la devolución si el envase vuelve).
--
-- 2) Mostrador sin envío = EN_PODER_CLIENTE.
--    Al guardar la venta, ven_crear_comprobante reserva en PENDIENTE_ENVIO
--    todo cilindro vendido que seguía DISPONIBLE — en ese momento aún no se
--    sabe si se despacha. Si el usuario responde "no es para envío" no se
--    crea orden de salida, y esa reserva se queda sin dueño: nadie la libera
--    y el cilindro queda inmovilizado (ni vendible ni en poder del cliente).
--    La nueva ven_confirmar_entrega_mostrador lo cierra dejándolo donde
--    realmente está, con el mismo desenlace que da el reparto culminado.
--    Como contrapartida, la liberación residual de ven_eliminar_comprobante
--    acepta EN_PODER_CLIENTE: sin reparto realizado (ya bloqueado arriba) el
--    único camino a ese estado es el mostrador, y ahí anular sí devuelve el
--    cilindro al almacén de la venta.
--
-- Además: ven_revertir_efectos_comprobante hacía PERFORM sobre
-- inv_revertir_por_documento, que reporta sus fallos como JSON. El error se
-- descartaba y la anulación seguía con el kardex a medio revertir. Ahora se
-- inspecta el resultado y se RAISE (rollback).
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_venta_custodia_mostrador_anular.sql
-- ============================================================


-- ------------------------------------------------------------
-- ven_confirmar_entrega_mostrador (nueva)
--
-- Solo toca los cilindros de ESTA venta que siguen en PENDIENTE_ENVIO: los de
-- préstamo ya están PRESTADO_CLIENTE y los de garantía entran al almacén.
-- Idempotente (segunda llamada actualiza cero filas) y se niega a correr si la
-- venta tiene una orden de salida vigente, que es la dueña de la reserva.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS ven_confirmar_entrega_mostrador(p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_confirmar_entrega_mostrador(
    p_id_comprobante integer,
    p_id_usuario integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_pend_envio INTEGER;
    v_id_en_poder INTEGER;
    v_actualizados INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT c.id_cliente INTO v_id_cliente
    FROM ven_comprobante c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La venta no existe o está anulada', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id_comprobante
          AND d.estado = 1
          AND UPPER(TRIM(ec.nombre)) <> 'ANULADA'
    ) THEN
        RETURN json_build_object(
            'error',
            'La venta tiene una orden de salida vigente: la entrega se cierra al culminar el reparto',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_en_poder
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_PODER_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_pend_envio IS NULL OR v_id_en_poder IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan los estados PENDIENTE_ENVIO o EN_PODER_CLIENTE en el catálogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    -- No pasa por inv_registrar_movimiento a propósito: el kardex ya lo movió
    -- la venta. Esto solo corrige dónde está físicamente el envase.
    UPDATE bal_balon b
    SET id_estado_balon = v_id_en_poder,
        id_cliente_ubicacion = COALESCE(b.id_cliente_ubicacion, v_id_cliente),
        id_almacen = NULL,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    FROM ven_comprobante_detalle d
    WHERE d.id_comprobante = p_id_comprobante
      AND d.estado = 1
      AND d.id_balon = b.id
      AND b.estado = 1
      AND b.id_estado_balon = v_id_pend_envio
      AND COALESCE(d.descripcion, '') !~* 'garant[ií]a';

    GET DIAGNOSTICS v_actualizados = ROW_COUNT;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'id', p_id_comprobante,
            'balones_actualizados', v_actualizados
        )
    );
END;
$function$;


-- ------------------------------------------------------------
-- doc_anular_salida: un REPARTO REALIZADA bloquea la anulación
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS doc_anular_salida(p_id integer, p_motivo character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_anular_salida(p_id integer, p_motivo character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_compra RECORD;
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

    -- Orden de planta con factura vinculada: la compra tiene su gas del retorno
    -- etiquetado COMPRA, que la reversa por ORDEN_SALIDA no alcanza. Anular la
    -- compra primero (que desvincula y ajusta el gas) deja todo consistente.
    IF v_doc.id_comprobante_compra IS NOT NULL AND EXISTS (
        SELECT 1 FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra AND c.estado = 1
    ) THEN
        SELECT c.serie, c.numero INTO v_compra
        FROM com_comprobante_compra c
        WHERE c.id = v_doc.id_comprobante_compra;

        RETURN json_build_object(
            'error', format(
                'La orden tiene la compra %s vinculada; anúlala primero en Compras',
                COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), ''), '#' || v_doc.id_comprobante_compra)
            ),
            'registro', NULL
        );
    END IF;

    -- Entrega ya realizada: los cilindros pasaron a EN_PODER_CLIENTE y el
    -- cliente se quedó con ellos. Anular repondría stock inexistente, así que
    -- se bloquea aquí y también en la cascada desde ven_eliminar_comprobante.
    IF EXISTS (
        SELECT 1
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_doc_salida = p_id
          AND a.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'error',
            'El reparto de esta orden ya fue entregado al cliente; no se puede anular. '
            || 'Registra la devolución de los cilindros o emite una nota de crédito.',
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

    -- El estado ANULADA se resuelve antes de revertir inventario: si faltara en
    -- el catálogo, el error soft se devolvía con los movimientos ya revertidos y
    -- la orden seguía activa.
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


-- ------------------------------------------------------------
-- ven_revertir_efectos_comprobante: el error soft de inv_revertir aborta
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS ven_revertir_efectos_comprobante(p_id integer, p_id_usuario_auditoria integer, p_exigir_sin_pagos boolean);

CREATE OR REPLACE FUNCTION ven_revertir_efectos_comprobante(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_exigir_sin_pagos boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_hay_pagos BOOLEAN;
    v_codigo_tipo VARCHAR;
    v_nombre_tipo_venta VARCHAR;
    v_codigo_tipo_documento VARCHAR;
    v_rev_inv JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(p_id, NULL);

    IF p_exigir_sin_pagos AND v_hay_pagos THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', 'No se puede eliminar: la cuenta por cobrar tiene pagos. Anule primero los pagos en Finanzas.'
        );
    END IF;

    -- Resolver el código del tipo de documento para inv_revertir_por_documento
    SELECT
        tc.descripcion,
        COALESCE(tv.nombre, 'VENTA')
    INTO v_codigo_tipo, v_nombre_tipo_venta
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
    WHERE c.id = p_id AND c.estado = 1;

    v_codigo_tipo_documento := ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta);

    -- Revertir kardex unificado (producto + balón) vía inv_movimiento
    v_rev_inv := inv_revertir_por_documento(
        v_codigo_tipo_documento,
        p_id,
        p_id_usuario_auditoria
    );

    IF v_rev_inv->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_rev_inv->>'error';
    END IF;

    IF NOT v_hay_pagos THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id, NULL);
    END IF;

    BEGIN
        PERFORM ven_cerrar_custodia_comprobante(p_id, p_id_usuario_auditoria);
    EXCEPTION WHEN OTHERS THEN
        RETURN json_build_object('ok', FALSE, 'error', SQLERRM);
    END;

    RETURN json_build_object('ok', TRUE, 'error', NULL);
END;
$function$;


-- ------------------------------------------------------------
-- ven_eliminar_comprobante: bloqueo por reparto entregado + liberación de
-- cilindros que quedaron EN_PODER_CLIENTE por una venta de mostrador
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS ven_eliminar_comprobante(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.ven_eliminar_comprobante(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_rev JSON;
    v_anul JSON;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_os_id INTEGER;
    v_id_almacen_venta INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT es.nombre, c.serie, c.numero, c.id_almacen
    INTO v_estado_sunat, v_serie, v_numero, v_id_almacen_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado_sunat = 'ACEPTADO' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar un comprobante ya aceptado por SUNAT. Use nota de crédito o comunicación de baja.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque tiene documentos derivados (boleta/factura/nota)'
        );
    END IF;

    -- Reparto entregado: doc_anular_salida también lo bloquea, pero el mensaje
    -- se resuelve aquí para que la venta explique el motivo en sus términos.
    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN age_actividad a ON a.id_doc_salida = d.id AND a.estado = 1
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error',
            'La entrega de esta venta ya fue realizada y los cilindros están en poder del cliente; '
            || 'no se puede anular. Emite una nota de crédito y registra la devolución.'
        );
    END IF;

    -- Cascada OS ANTES del soft-delete: doc_anular_salida localiza balones
    -- por ven_comprobante_detalle (aún estado=1), libera PENDIENTE_ENVIO /
    -- EN_TRANSITO → DISPONIBLE, y falla con error si hay reparto vigente.
    -- PERFORM descartaba ese error; aquí se propaga.
    FOR v_os_id IN
        SELECT d.id
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND ec.nombre <> 'ANULADA'
    LOOP
        v_anul := doc_anular_salida(
            v_os_id,
            format('Venta %s-%s anulada', COALESCE(v_serie, ''), COALESCE(v_numero, p_id::text)),
            p_id_usuario_auditoria
        );
        IF v_anul->>'error' IS NOT NULL THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id,
                'error', v_anul->>'error'
            );
        END IF;
    END LOOP;

    -- Reserva de venta sin OS: ven_crear_comprobante dejó PENDIENTE_ENVIO en
    -- cilindros DISPONIBLE vendidos. Si no hubo OS (o quedó residual), liberar.
    -- Con OS vigente doc_anular_salida ya lo hizo; este UPDATE es no-op.
    --
    -- EN_PODER_CLIENTE también entra: es donde deja los cilindros la venta de
    -- mostrador sin orden de salida. El único otro camino a ese estado es el
    -- reparto culminado, y ese ya abortó la anulación más arriba.
    UPDATE bal_balon b
    SET id_estado_balon = lo_disp.id,
        id_almacen = COALESCE(b.id_almacen, v_id_almacen_venta),
        id_cliente_ubicacion = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM ven_comprobante_detalle d
    CROSS JOIN LATERAL (
        SELECT lo.id
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1
    ) lo_disp
    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE d.id_comprobante = p_id
      AND d.estado = 1
      AND d.id_balon = b.id
      AND b.estado = 1
      AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
      AND lo_disp.id IS NOT NULL
      AND UPPER(TRIM(eb.nombre)) IN ('PENDIENTE_ENVIO', 'EN_PODER_CLIENTE');

    -- Revertir stock, CxC impaga y custodia (préstamo/recarga/alquiler/GRE)
    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, TRUE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos del comprobante')
        );
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    -- Fase 3: las líneas de cobro siguen la suerte del comprobante. Los totales
    -- de caja ya excluyen las ventas anuladas por su cabecera, pero dejarlas
    -- activas haría que un listado de cobros por cuenta bancaria contara dinero
    -- de una venta que ya no existe.
    UPDATE ven_comprobante_pago
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
