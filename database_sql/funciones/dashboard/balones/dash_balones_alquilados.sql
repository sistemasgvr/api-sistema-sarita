-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_alquilados
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.643Z
DROP FUNCTION IF EXISTS dash_balones_alquilados(p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_balones_alquilados(p_id_cliente integer DEFAULT NULL::integer)
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
  WHERE gl.nombre = 'EstadoBalon' AND glo.nombre = 'ALQUILADO'
  LIMIT 1;

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(
      json_build_object(
        'idBalon', b.id,
        'codigoBalon', b.codigo_balon,
        'tipoBalon', tb.nombre,
        'idCliente', c.id,
        'cliente', COALESCE(c.razon_social, c.nombres),
        'fechaInicio', al.fecha_inicio,
        'fechaFinPactada', al.fecha_fin_pactada
      )
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_balon b
  LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
  LEFT JOIN cli_clientes c ON c.id = b.id_cliente_ubicacion
  LEFT JOIN LATERAL (
    SELECT al.fecha_inicio, al.fecha_fin_pactada
    FROM bal_alquiler_detalle ad
    JOIN bal_alquiler al ON al.id = ad.id_alquiler
    WHERE ad.id_balon = b.id
      AND ad.fecha_devolucion IS NULL
      AND ad.estado = 1
    ORDER BY al.fecha_inicio DESC
    LIMIT 1
  ) al ON TRUE
  WHERE b.id_estado_balon = v_id_estado
    AND b.estado = 1
    AND (p_id_cliente IS NULL OR b.id_cliente_ubicacion = p_id_cliente);

  RETURN v_result;
END;
$function$
