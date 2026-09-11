-- Function: bal_sync_ph_desde_orden_salida
-- Creada: 2026-09-10 (migración 20260910_retorno_fisico_fecha_ph).
--
-- Equivalente a bal_sync_ph_desde_recarga para la recarga en planta externa:
-- la fecha de P.H. que se registra con el retorno es una prueba real hecha en
-- planta, así que tiene que llegar al libro de P.H. de cada cilindro. Antes
-- quedaba solo en la cabecera del documento y los balones seguían con la
-- vigencia vieja (y aparecían en "P.H. por vencer" con la prueba recién hecha).
--
-- Solo la llama bal_finalizar_recarga_planta y solo cuando el retorno físico
-- está registrado: sin cilindros de vuelta no hay prueba que anotar.
--
-- Idempotente por (id_doc_salida, id_balon): reenviar el retorno o corregir la
-- fecha no genera filas duplicadas en el historial.
DROP FUNCTION IF EXISTS bal_sync_ph_desde_orden_salida(p_id_doc_salida integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_sync_ph_desde_orden_salida(p_id_doc_salida integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_id_balon INTEGER;
    v_observacion VARCHAR;
BEGIN
    SELECT d.id, d.numero, d.fecha_prueba_hidrostatica
    INTO v_doc
    FROM doc_salida d
    WHERE d.id = p_id_doc_salida AND d.estado = 1;

    IF NOT FOUND OR v_doc.fecha_prueba_hidrostatica IS NULL THEN
        RETURN;
    END IF;

    v_observacion := format(
        'Retorno de recarga en planta externa (orden %s)',
        COALESCE(NULLIF(TRIM(v_doc.numero), ''), '#' || p_id_doc_salida)
    );

    FOR v_id_balon IN
        SELECT DISTINCT dd.id_balon
        FROM doc_salida_detalle dd
        WHERE dd.id_doc_salida = p_id_doc_salida
          AND dd.estado = 1
          AND dd.id_balon IS NOT NULL
    LOOP
        CONTINUE WHEN EXISTS (
            SELECT 1
            FROM bal_balon_ph_historial
            WHERE id_doc_salida = p_id_doc_salida
              AND id_balon = v_id_balon
              AND estado = 1
        );

        PERFORM bal_registrar_ph_historial(
            p_id_balon             => v_id_balon,
            p_fecha_prueba         => v_doc.fecha_prueba_hidrostatica,
            p_observacion          => v_observacion,
            p_id_doc_salida        => p_id_doc_salida,
            p_id_usuario_auditoria => p_id_usuario_auditoria
        );
    END LOOP;
END;
$function$;
