-- Balones en almacén. Filtro opcional por cliente (ubicación).

DROP FUNCTION IF EXISTS dash_balones_en_almacen();

CREATE OR REPLACE FUNCTION dash_balones_en_almacen(
    p_id_cliente INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
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
$$;
