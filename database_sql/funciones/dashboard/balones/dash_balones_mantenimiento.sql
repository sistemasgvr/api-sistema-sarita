-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS dash_balones_mantenimiento(p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_balones_mantenimiento(p_id_cliente integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id_pendiente INT;
  v_id_en_proceso INT;
  v_result JSON;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT glo.id INTO v_id_pendiente
  FROM gen_lista_opciones glo
  JOIN gen_lista gl ON gl.id = glo.id_lista
  WHERE gl.nombre = 'EstadoDocumento' AND glo.nombre = 'PENDIENTE'
  LIMIT 1;

  SELECT glo.id INTO v_id_en_proceso
  FROM gen_lista_opciones glo
  JOIN gen_lista gl ON gl.id = glo.id_lista
  WHERE gl.nombre = 'EstadoDocumento' AND glo.nombre = 'EN_PROCESO'
  LIMIT 1;

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(
      json_build_object(
        'idBalon', b.id,
        'codigoBalon', b.codigo_balon,
        'tipoBalon', tb.nombre,
        'tipoMantenimiento', tm.nombre,
        'fechaIngreso', m.fecha_ingreso,
        'esExterno', m.es_externo
      )
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_mantenimiento m
  JOIN bal_balon b ON b.id = m.id_balon
  LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
  LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_mantenimiento
  WHERE m.id_estado IN (v_id_pendiente, v_id_en_proceso)
    AND m.estado = 1
    AND (p_id_cliente IS NULL OR b.id_cliente_ubicacion = p_id_cliente);

  RETURN v_result;
END;
$function$;
