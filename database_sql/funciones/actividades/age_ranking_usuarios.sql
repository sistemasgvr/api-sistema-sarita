-- Function: age_ranking_usuarios
-- Fase 6 (apunte 8.b.i.6) — ranking de colaboradores por actividades en un rango.
--
-- Cuenta por responsable, no por quien creó el registro: lo que interesa medir
-- es quién sale a hacer el trabajo, no quién lo tipeó en el sistema.
DROP FUNCTION IF EXISTS age_ranking_usuarios(p_fecha_desde date, p_fecha_hasta date, p_limite integer);

CREATE OR REPLACE FUNCTION age_ranking_usuarios(p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_limite integer DEFAULT 20)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM age_actividad a
    WHERE a.estado = 1
      AND (p_fecha_desde IS NULL OR a.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR a.fecha_programada <= p_fecha_hasta);

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.total DESC, t.nombre), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            COALESCE(a.id_trabajador_responsable, a.id_usuario_responsable) AS id_responsable,
            COALESCE(
                NULLIF(TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)), ''),
                u.nombre,
                'Sin responsable'
            ) AS nombre,
            COUNT(*)::INT AS total,
            COUNT(*) FILTER (WHERE ea.nombre = 'REALIZADA')::INT AS realizadas,
            COUNT(*) FILTER (WHERE ea.nombre = 'PENDIENTE')::INT AS pendientes,
            COUNT(*) FILTER (WHERE ea.nombre = 'CANCELADA')::INT AS canceladas,
            COUNT(*) FILTER (WHERE ta.nombre = 'REPARTO')::INT AS repartos,
            COUNT(*) FILTER (WHERE ta.nombre = 'RECOJO')::INT AS recojos
        FROM age_actividad a
        LEFT JOIN tra_trabajadores tr ON tr.id = a.id_trabajador_responsable
        LEFT JOIN auth_usuarios u ON u.id = a.id_usuario_responsable
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        WHERE a.estado = 1
          AND (p_fecha_desde IS NULL OR a.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR a.fecha_programada <= p_fecha_hasta)
        GROUP BY 1, 2
        ORDER BY total DESC
        LIMIT GREATEST(COALESCE(p_limite, 20), 1)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
