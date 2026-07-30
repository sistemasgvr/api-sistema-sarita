CREATE OR REPLACE FUNCTION bal_listar_estado_historial(
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
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registros', '[]'::JSON, 'total', 0);
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM bal_balon_estado_historial h
    WHERE h.id_balon = p_id_balon AND h.estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            h.id,
            h.id_balon,
            h.tipo_evento,
            CASE h.tipo_evento
                WHEN 'SOLICITUD_BAJA' THEN 'Solicitud de baja'
                WHEN 'BAJA_APROBADA' THEN 'Baja aprobada'
                WHEN 'BAJA_RECHAZADA' THEN 'Baja rechazada'
                WHEN 'REACTIVACION' THEN 'Reactivación'
                ELSE h.tipo_evento
            END AS nombre_tipo_evento,
            h.id_baja,
            h.id_motivo_baja,
            mb.nombre AS nombre_motivo_baja,
            h.id_estado_anterior,
            ea.nombre AS nombre_estado_anterior,
            h.id_estado_nuevo,
            en.nombre AS nombre_estado_nuevo,
            h.observacion,
            h.id_usuario,
            u.nombre AS nombre_usuario,
            h.fecha_evento,
            h.fecha_creacion
        FROM bal_balon_estado_historial h
        LEFT JOIN gen_lista_opciones mb ON h.id_motivo_baja = mb.id
        LEFT JOIN gen_lista_opciones ea ON h.id_estado_anterior = ea.id
        LEFT JOIN gen_lista_opciones en ON h.id_estado_nuevo = en.id
        LEFT JOIN auth_usuarios u ON h.id_usuario = u.id
        WHERE h.id_balon = p_id_balon AND h.estado = 1
        ORDER BY h.fecha_evento DESC, h.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
