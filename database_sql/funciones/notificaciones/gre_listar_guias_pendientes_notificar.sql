-- Guías de remisión con ticket SUNAT aún en PENDIENTE desde hace >= p_dias_min días.
CREATE OR REPLACE FUNCTION gre_listar_guias_pendientes_notificar(
    p_dias_min INTEGER DEFAULT 1,
    p_fecha DATE DEFAULT NULL
)
RETURNS JSON
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
$function$;
