-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_en_almacen
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.645Z
DROP FUNCTION IF EXISTS dash_balones_en_almacen(p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_balones_en_almacen(p_id_cliente integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id_estado INT;
  v_result JSON;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT glo.id INTO v_id_estado
  FROM gen_lista_opciones glo
  JOIN gen_lista gl ON gl.id = glo.id_lista
  WHERE gl.nombre = 'EstadoBalon' AND glo.nombre = 'EN_ALMACEN'
  LIMIT 1;

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(
      json_build_object(
        'idBalon', b.id,
        'codigoBalon', b.codigo_balon,
        'tipoBalon', tb.nombre,
        'idAlmacen', b.id_almacen,
        'almacen', a.nombre
      )
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_balon b
  LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
  LEFT JOIN gen_almacen a ON a.id = b.id_almacen
  WHERE b.id_estado_balon = v_id_estado
    AND b.estado = 1
    AND (p_id_cliente IS NULL OR b.id_cliente_ubicacion = p_id_cliente);

  RETURN v_result;
END;
$function$
