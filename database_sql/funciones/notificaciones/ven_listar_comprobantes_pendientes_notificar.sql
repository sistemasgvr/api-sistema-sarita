-- Comprobantes con ticket SUNAT aún en PENDIENTE desde hace >= p_dias_min días.
CREATE OR REPLACE FUNCTION ven_listar_comprobantes_pendientes_notificar(
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
            'id', c.id,
            'serie', c.serie,
            'numero', c.numero,
            'fecha', c.fecha,
            'ticket_sunat', c.ticket_sunat,
            'dias_pendiente', (v_fecha - c.fecha),
            'codigo_tipo_comprobante', tc.codigo,
            'nombre_tipo_comprobante', tc.nombre,
            'nombre_estado_sunat', es.nombre
        ) AS row_data,
        c.id,
        c.fecha
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
        WHERE c.estado = 1
          AND COALESCE(es.nombre, '') = 'PENDIENTE'
          AND NULLIF(TRIM(c.ticket_sunat), '') IS NOT NULL
          AND c.fecha IS NOT NULL
          AND (v_fecha - c.fecha) >= v_min
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
