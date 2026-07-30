-- Licencias activas que vencen entre p_dias_min y p_dias_max días (inclusive).
CREATE OR REPLACE FUNCTION gen_listar_licencias_por_vencer_notificar(
    p_dias_min INTEGER DEFAULT 3,
    p_dias_max INTEGER DEFAULT 7,
    p_fecha DATE DEFAULT NULL
)
RETURNS JSON
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
            'id', gl.id,
            'codigo', gl.codigo,
            'fecha_vencimiento', gl.fecha_vencimiento,
            'dias_para_vencer', (gl.fecha_vencimiento - v_fecha),
            'nombre_tipo_licencia', tlo.nombre,
            'nombre_categoria_licencia', clo.nombre,
            'chofer_nombre', TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)),
            'id_chofer', gl.id_chofer
        ) AS row_data,
        gl.id,
        gl.fecha_vencimiento
        FROM gen_licencia gl
        LEFT JOIN gen_chofer ch ON ch.id = gl.id_chofer
        LEFT JOIN gen_lista_opciones tlo ON tlo.id = gl.id_tipo_licencia
        LEFT JOIN gen_lista_opciones clo ON clo.id = gl.id_categoria_licencia
        WHERE gl.estado = 1
          AND gl.fecha_vencimiento IS NOT NULL
          AND gl.fecha_vencimiento BETWEEN (v_fecha + v_min) AND (v_fecha + v_max)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
