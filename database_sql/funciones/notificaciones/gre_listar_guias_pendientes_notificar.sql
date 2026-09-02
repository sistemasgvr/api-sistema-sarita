-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gre_listar_guias_pendientes_notificar
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.757Z
DROP FUNCTION IF EXISTS gre_listar_guias_pendientes_notificar(p_dias_min integer, p_fecha date);

CREATE OR REPLACE FUNCTION gre_listar_guias_pendientes_notificar(p_dias_min integer DEFAULT 1, p_fecha date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_min INTEGER;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_min := GREATEST(COALESCE(p_dias_min, 1), 0);

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha, t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id', g.id,
            'serie', g.serie,
            'numero', g.numero,
            'fecha', g.fecha,
            'ticket_sunat', g.ticket_sunat,
            'dias_pendiente', (v_fecha - g.fecha),
            'nombre_estado_sunat', es.nombre
        ) AS row_data,
        g.id,
        g.fecha
        FROM gre_guia_remision g
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND COALESCE(es.nombre, '') = 'PENDIENTE'
          AND NULLIF(TRIM(g.ticket_sunat), '') IS NOT NULL
          AND g.fecha IS NOT NULL
          AND (v_fecha - g.fecha) >= v_min
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$
