-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_documentos_vencidos_notificar
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.731Z
DROP FUNCTION IF EXISTS gen_listar_documentos_vencidos_notificar(p_fecha date);

CREATE OR REPLACE FUNCTION gen_listar_documentos_vencidos_notificar(p_fecha date DEFAULT NULL::date)
 RETURNS json
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
            'id', dv.id,
            'descripcion', dv.descripcion,
            'numero_documento', dv.numero_documento,
            'fecha_vencimiento', dv.fecha_vencimiento,
            'dias_vencido', (v_fecha - dv.fecha_vencimiento),
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
          AND dv.fecha_vencimiento < v_fecha
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$
