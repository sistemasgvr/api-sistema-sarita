-- ============================================================
-- Migración: GRE pendiente al anular / NC de un comprobante → doc_anular_salida
-- Fecha: 2026-09-11
--
-- Bug latente: ven_cerrar_custodia_comprobante (anulación del CPE y NC total)
-- llamaba a gre_eliminar_guia_remision para dar de baja la guía pendiente que
-- referencia el comprobante. Esa función pertenece al modelo gre_guia_remision,
-- anterior a doc_salida (F2), y ya no existe en la BD: cualquier anulación o
-- NC total con una GRE pendiente fallaba con "function does not exist".
--
-- Qué cambia
--  1) ven_cerrar_custodia_comprobante: la GRE (doc_salida no ANULADA, no
--     aceptada ni emitida a SUNAT) que referencia el CPE por
--     doc_salida_referencia se anula con doc_anular_salida, que revierte la
--     salida de inventario y libera la custodia de los cilindros. Un error de
--     doc_anular_salida (ticket SUNAT pendiente, reparto vigente) se propaga y
--     frena la anulación, igual que antes.
--  2) DROP de bal_aplicar_salidas_guia_remision y
--     bal_revertir_salidas_guia_remision: eran el movimiento de balones de la
--     GRE del modelo viejo; hoy lo hace doc_generar_salida / doc_anular_salida
--     y nadie las llama (ni API, ni otra función, ni trigger).
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_gre_anular_por_doc_salida.sql
-- ============================================================


-- ===== funciones\comprobantes\ven_cerrar_custodia_comprobante.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_cerrar_custodia_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
-- Actualizada por database_sql/migraciones/20260911_recojos_solo_actividades.sql:
-- bal_devolver_regulador_alquiler ya no recibe p_id_recojo.
--
-- Actualizada por database_sql/migraciones/20260911_gre_anular_por_doc_salida.sql:
-- la GRE pendiente que referencia el CPE se anula con doc_anular_salida.
-- Antes llamaba a gre_eliminar_guia_remision (modelo gre_guia_remision,
-- anterior a doc_salida) que ya no existe en la BD: anular o emitir NC total
-- de un comprobante con guía pendiente fallaba con "function does not exist".
--
-- Actualizada por database_sql/migraciones/20260911_alquiler_solo_regulador.sql:
-- sin loop de bal_alquiler_detalle (tabla eliminada; el alquiler es solo regulador).
DROP FUNCTION IF EXISTS ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle RECORD;
    v_recarga RECORD;
    v_alquiler RECORD;
    v_guia RECORD;
    v_mant RECORD;
    v_result JSON;
    v_id_en_almacen INTEGER;
    v_id_estado_final INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    -- Préstamos: devolver cilindros pendientes y cerrar cabecera
    FOR v_prestamo IN
        SELECT id FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        FOR v_detalle IN
            SELECT id FROM bal_prestamo_detalle
            WHERE estado = 1 AND id_prestamo = v_prestamo.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_prestamo_detalle(
                v_detalle.id,
                CURRENT_DATE,
                NULL,
                p_id_usuario,
                'VACIO',
                'Devolución automática por anulación/NC del comprobante'
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END LOOP;

    -- Recargas mostrador: devolver el gas a pro_stock y soltar el balón (inv_movimiento)
    FOR v_recarga IN
        SELECT id, id_balon
        FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id_comprobante
    LOOP
        v_result := inv_revertir_por_documento('RECARGA', v_recarga.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);

        UPDATE bal_movimiento_recarga
        SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
        WHERE id = v_recarga.id AND estado = 1;
    END LOOP;

    -- Alquileres: reingreso del regulador/accesorio (el alquiler no lleva
    -- cilindros; esos van por préstamo). bal_devolver_regulador_alquiler ya
    -- finaliza el contrato; el UPDATE de abajo cubre un alquiler sin accesorio.
    FOR v_alquiler IN
        SELECT id FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        v_result := bal_devolver_regulador_alquiler(
            v_alquiler.id,
            CURRENT_DATE,
            'BUENO',
            'Devolución automática por anulación/NC del comprobante',
            p_id_usuario
        );
        IF v_result->>'error' IS NOT NULL
           AND v_result->>'error' NOT ILIKE '%no tiene regulador%'
        THEN
            PERFORM ven_raise_si_error(v_result);
        END IF;

        SELECT lo.id INTO v_id_estado_final
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, CURRENT_DATE),
            id_estado = COALESCE(v_id_estado_final, id_estado),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_alquiler.id AND estado = 1;
    END LOOP;

    -- GRE (doc_salida) no aceptada por SUNAT que referencia este CPE.
    -- Las guías viven en doc_salida desde F2; se anulan con doc_anular_salida,
    -- que revierte la salida de inventario y libera la custodia de los
    -- cilindros (PENDIENTE_ENVIO / EN_TRANSITO → DISPONIBLE). Es idempotente
    -- sobre una ya ANULADA (p. ej. la OS de la venta que ven_eliminar_comprobante
    -- anuló antes por id_venta) y falla en claro si la guía tiene ticket SUNAT
    -- pendiente o un reparto vigente: ese error sí debe frenar la anulación.
    FOR v_guia IN
        SELECT DISTINCT g.id, c.serie, c.numero
        FROM doc_salida g
        INNER JOIN doc_salida_referencia r ON r.id_doc_salida = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        INNER JOIN gen_lista_opciones ec ON ec.id = g.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND ec.nombre <> 'ANULADA'
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
          AND NOT COALESCE(g.emitido_sunat, FALSE)
    LOOP
        v_result := doc_anular_salida(
            v_guia.id,
            format(
                'Comprobante %s-%s anulado / con nota de crédito',
                COALESCE(v_guia.serie, ''),
                COALESCE(v_guia.numero, p_id_comprobante::TEXT)
            ),
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Mantenimiento no finalizado ligado al CPE
    FOR v_mant IN
        SELECT m.id, m.id_balon, em.nombre AS nombre_estado
        FROM bal_mantenimiento m
        LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
        WHERE m.estado = 1 AND m.id_comprobante_venta = p_id_comprobante
    LOOP
        IF UPPER(COALESCE(v_mant.nombre_estado, '')) = 'FINALIZADO' THEN
            CONTINUE;
        END IF;

        UPDATE bal_mantenimiento
        SET
            estado = 0,
            id_comprobante_venta = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_mant.id AND estado = 1;

        SELECT lo.id INTO v_id_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon b
        SET
            id_estado_balon = COALESCE(v_id_en_almacen, b.id_estado_balon),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.id = v_mant.id_balon
          AND b.estado = 1
          AND EXISTS (
              SELECT 1 FROM gen_lista_opciones eb
              WHERE eb.id = b.id_estado_balon
                AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
          );
    END LOOP;

    -- Garantía sin reembolsos: se da de baja el cobro documental (el efectivo iba en el CPE)
    UPDATE ven_garantia_movimiento gm
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE gm.estado = 1
      AND gm.id_comprobante = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1
          FROM ven_garantia_movimiento d
          INNER JOIN gen_lista_opciones td ON td.id = d.id_tipo_movimiento
          WHERE d.id_garantia = gm.id_garantia
            AND d.estado = 1
            AND UPPER(td.nombre) = 'DEVOLUCION'
      );

    UPDATE ven_garantia g
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE g.estado = 1
      AND COALESCE(g.monto_devuelto, 0) = 0
      AND NOT EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm
          WHERE gm.id_garantia = g.id AND gm.estado = 1
      )
      AND EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm0
          WHERE gm0.id_garantia = g.id AND gm0.id_comprobante = p_id_comprobante
      );
END;
$function$;


-- ============================================================
-- DROP funciones huérfanas del modelo GRE anterior a doc_salida
-- ============================================================
DROP FUNCTION IF EXISTS bal_aplicar_salidas_guia_remision(integer, integer);
DROP FUNCTION IF EXISTS bal_revertir_salidas_guia_remision(integer, integer, integer);
DO $mig$
DECLARE v_f RECORD;
BEGIN
    -- Por si quedara alguna sobrecarga con otra firma.
    FOR v_f IN
        SELECT p.oid::regprocedure AS firma
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('bal_aplicar_salidas_guia_remision', 'bal_revertir_salidas_guia_remision', 'gre_eliminar_guia_remision')
    LOOP
        EXECUTE format('DROP FUNCTION %s', v_f.firma);
    END LOOP;
END
$mig$;
