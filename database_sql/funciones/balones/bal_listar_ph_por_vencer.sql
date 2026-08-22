-- Cilindros activos con PH por vencer dentro de p_dias (America/Lima).
CREATE OR REPLACE FUNCTION bal_listar_ph_por_vencer(
    p_dias INTEGER DEFAULT 60
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_dias INTEGER;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_dias := GREATEST(COALESCE(p_dias, 60), 0);

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha_proxima, t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id', b.id,
            'codigo_balon', b.codigo_balon,
            'fecha_proxima', b.fecha_proxima_prueba_hidrostatica,
            'dias_restantes', (b.fecha_proxima_prueba_hidrostatica - CURRENT_DATE)
        ) AS row_data,
        b.id,
        b.fecha_proxima_prueba_hidrostatica AS fecha_proxima
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
          AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
          AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => v_dias)
          AND COALESCE(eb.nombre, '') NOT IN ('DADO_DE_BAJA', 'ROBO')
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
