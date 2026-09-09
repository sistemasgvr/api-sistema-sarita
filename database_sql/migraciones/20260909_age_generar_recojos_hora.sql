-- Function: age_generar_recojos_por_vencer
-- Fase 6 (apunte 8.b.i.5) — auto-registro de la actividad de recojo.
--
-- Recorre los préstamos cuyo retorno pactado cae dentro de la ventana y crea su
-- actividad de recojo. Se apoya en age_crear_recojo_prestamo, que es idempotente
-- por préstamo, así que correrlo a diario no genera duplicados.
--
-- p_dias_antes: ventana hacia adelante. 0 = solo los ya vencidos.
--   El valor operativo lo decide el negocio (decisión 12 del plan); mientras no
--   esté fijado, quien llama al job pasa el que quiera y el default es 3.
-- p_id_trabajador_responsable: a quién se asigna. NULL = sin asignar, para que
--   el encargado reparta desde la agenda.
DROP FUNCTION IF EXISTS age_generar_recojos_por_vencer(p_dias_antes integer, p_id_trabajador_responsable integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_generar_recojos_por_vencer(p_dias_antes integer DEFAULT 3, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo   RECORD;
    v_res        JSON;
    v_creadas    INTEGER := 0;
    v_existentes INTEGER := 0;
    v_ids        INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    FOR v_prestamo IN
        SELECT DISTINCT p.id, p.fecha_retorno_pactada
        FROM bal_prestamo p
        JOIN bal_prestamo_detalle pd
          ON pd.id_prestamo = p.id
         AND pd.estado = 1
         AND pd.fecha_devolucion IS NULL
         AND pd.id_balon IS NOT NULL
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND p.fecha_retorno_pactada IS NOT NULL
          AND p.fecha_retorno_pactada <= CURRENT_DATE + GREATEST(COALESCE(p_dias_antes, 3), 0)
          AND COALESCE(ep.nombre, '') NOT IN ('CERRADO', 'CANCELADO', 'DEVUELTO')
        ORDER BY p.fecha_retorno_pactada
    LOOP
        v_res := age_crear_recojo_prestamo(
            p_id_prestamo               => v_prestamo.id,
            p_fecha_programada          => v_prestamo.fecha_retorno_pactada,
            p_hora_inicio_estimada      => TIME '08:00',
            p_id_trabajador_responsable => p_id_trabajador_responsable,
            p_observaciones             => 'Generada automáticamente por vencimiento del préstamo',
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            -- Un préstamo con datos inconsistentes no debe frenar al resto.
            CONTINUE;
        END IF;

        IF (v_res->'registro'->>'creada')::BOOLEAN THEN
            v_creadas := v_creadas + 1;
            v_ids := v_ids || (v_res->'registro'->>'id')::INTEGER;
        ELSE
            v_existentes := v_existentes + 1;
        END IF;
    END LOOP;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'dias_antes', GREATEST(COALESCE(p_dias_antes, 3), 0),
            'creadas', v_creadas,
            'ya_existian', v_existentes,
            'id_actividades', array_to_json(v_ids)
        )
    );
END;
$function$;
