-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_ph_por_vencer
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS dash_balones_ph_por_vencer(p_dias_alerta integer, p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_balones_ph_por_vencer(p_dias_alerta integer DEFAULT 30, p_id_cliente integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id_baja INT;
  v_result JSON;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT glo.id INTO v_id_baja
  FROM gen_lista_opciones glo
  JOIN gen_lista gl ON gl.id = glo.id_lista
  WHERE gl.nombre = 'EstadoBalon' AND glo.nombre = 'DADO_DE_BAJA'
  LIMIT 1;

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(
      json_build_object(
        'idBalon', b.id,
        'codigoBalon', b.codigo_balon,
        'tipoBalon', tb.nombre,
        'fechaProximaPh', b.fecha_proxima_prueba_hidrostatica,
        'diasRestantes', (b.fecha_proxima_prueba_hidrostatica - CURRENT_DATE),
        'vencido', (b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE)
      )
      ORDER BY b.fecha_proxima_prueba_hidrostatica
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_balon b
  LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
  WHERE b.fecha_proxima_prueba_hidrostatica IS NOT NULL
    AND b.fecha_proxima_prueba_hidrostatica <= (CURRENT_DATE + (p_dias_alerta || ' days')::INTERVAL)
    AND (v_id_baja IS NULL OR b.id_estado_balon IS DISTINCT FROM v_id_baja)
    AND b.estado = 1
    AND (p_id_cliente IS NULL OR b.id_cliente_ubicacion = p_id_cliente);

  RETURN v_result;
END;
$function$;
