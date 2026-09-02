-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_documentos_por_vencer_notificar
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.730Z
DROP FUNCTION IF EXISTS gen_listar_documentos_por_vencer_notificar(p_dias_min integer, p_dias_max integer, p_fecha date);

CREATE OR REPLACE FUNCTION gen_listar_documentos_por_vencer_notificar(p_dias_min integer DEFAULT 3, p_dias_max integer DEFAULT 7, p_fecha date DEFAULT NULL::date)
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
            'id', dv.id,
            'descripcion', dv.descripcion,
            'numero_documento', dv.numero_documento,
            'fecha_vencimiento', dv.fecha_vencimiento,
            'dias_para_vencer', (dv.fecha_vencimiento - v_fecha),
            'nombre_categoria', cat.nombre,
            'id_vehiculo', dv.id_vehiculo,
            'vehiculo_placa', v.placa,
            'nombre_estado', est.nombre
        ) AS row_data,
        dv.id,
        dv.fecha_vencimiento
        FROM gen_documento_vencimiento dv
        LEFT JOIN gen_lista_opciones cat ON cat.id = dv.id_categoria
        LEFT JOIN gen_vehiculo v ON v.id = dv.id_vehiculo
        LEFT JOIN gen_lista_opciones est ON est.id = dv.id_estado
        WHERE dv.estado = 1
          AND dv.fecha_vencimiento IS NOT NULL
          AND dv.fecha_vencimiento BETWEEN (v_fecha + v_min) AND (v_fecha + v_max)
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$
