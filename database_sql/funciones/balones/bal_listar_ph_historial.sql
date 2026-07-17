CREATE OR REPLACE FUNCTION bal_listar_ph_historial(
    p_id_balon INTEGER,
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
        RETURN json_build_object('registros', '[]'::JSON, 'total', 0);
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM bal_balon_ph_historial h
    WHERE h.id_balon = p_id_balon AND h.estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            h.id,
            h.id_balon,
            h.fecha_prueba,
            h.vigencia_anios,
            h.fecha_proxima,
            h.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            h.organo_inspector_no_aplica,
            h.numero_certificado,
            h.id_mantenimiento,
            h.id_movimiento_recarga,
            h.es_vigente,
            h.observacion,
            h.fecha_creacion
        FROM bal_balon_ph_historial h
        LEFT JOIN gen_lista_opciones oi ON h.id_organo_inspector = oi.id
        WHERE h.id_balon = p_id_balon AND h.estado = 1
        ORDER BY h.fecha_prueba DESC, h.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
