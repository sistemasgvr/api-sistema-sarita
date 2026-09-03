-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_alquileres_por_vencer_notificar
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
DROP FUNCTION IF EXISTS bal_listar_alquileres_por_vencer_notificar(p_dias_min integer, p_dias_max integer, p_fecha date);

CREATE OR REPLACE FUNCTION bal_listar_alquileres_por_vencer_notificar(p_dias_min integer DEFAULT 3, p_dias_max integer DEFAULT 7, p_fecha date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_min INTEGER;
    v_max INTEGER;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_min := GREATEST(COALESCE(p_dias_min, 3), 0);
    v_max := GREATEST(COALESCE(p_dias_max, 7), v_min);

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha_vencimiento, t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id', a.id,
            'id_cliente', a.id_cliente,
            'nombre_cliente', COALESCE(c.razon_social, TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno))),
            'fecha_inicio', a.fecha_inicio,
            'fecha_fin_pactada', a.fecha_fin_pactada,
            'dias_periodo', a.dias_periodo,
            'fecha_vencimiento', COALESCE(per.fecha_fin, a.fecha_fin_pactada),
            'id_periodo', per.id,
            'numero_periodo', per.numero_periodo,
            'dias_para_vencer', (COALESCE(per.fecha_fin, a.fecha_fin_pactada) - v_fecha)
        ) AS row_data,
        a.id,
        COALESCE(per.fecha_fin, a.fecha_fin_pactada) AS fecha_vencimiento
        FROM bal_alquiler a
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN LATERAL (
            SELECT p.id, p.numero_periodo, p.fecha_fin
            FROM bal_alquiler_periodo p
            WHERE p.id_alquiler = a.id
              AND p.estado = 1
            ORDER BY p.numero_periodo DESC, p.id DESC
            LIMIT 1
        ) per ON TRUE
        WHERE a.estado = 1
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
          AND COALESCE(per.fecha_fin, a.fecha_fin_pactada) IS NOT NULL
          AND COALESCE(per.fecha_fin, a.fecha_fin_pactada)
              BETWEEN (v_fecha + v_min) AND (v_fecha + v_max)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
