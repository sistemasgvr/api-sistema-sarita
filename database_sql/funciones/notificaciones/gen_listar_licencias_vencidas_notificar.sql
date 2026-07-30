-- Licencias activas ya vencidas (fecha_vencimiento < hoy).
CREATE OR REPLACE FUNCTION gen_listar_licencias_vencidas_notificar(
    p_fecha DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha_vencimiento, t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT json_build_object(
            'id', gl.id,
            'codigo', gl.codigo,
            'fecha_vencimiento', gl.fecha_vencimiento,
            'dias_vencido', (v_fecha - gl.fecha_vencimiento),
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
          AND gl.fecha_vencimiento < v_fecha
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
