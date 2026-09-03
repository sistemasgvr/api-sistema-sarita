-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_prestados
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS dash_balones_prestados(p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_balones_prestados(p_id_cliente integer DEFAULT NULL::integer)
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
  WHERE gl.nombre = 'EstadoBalon' AND glo.nombre = 'PRESTADO_CLIENTE'
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
        'fechaPrestamo', pd.fecha_prestamo,
        'fechaVencimiento', pd.fecha_vencimiento
      )
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_balon b
  LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
  LEFT JOIN cli_clientes c ON c.id = b.id_cliente_ubicacion
  LEFT JOIN LATERAL (
    SELECT pd.fecha_prestamo, pd.fecha_vencimiento
    FROM bal_prestamo_detalle pd
    WHERE pd.id_balon = b.id
      AND pd.fecha_devolucion IS NULL
      AND pd.estado = 1
    ORDER BY pd.fecha_prestamo DESC
    LIMIT 1
  ) pd ON TRUE
  WHERE b.id_estado_balon = v_id_estado
    AND b.estado = 1
    AND (p_id_cliente IS NULL OR b.id_cliente_ubicacion = p_id_cliente);

  RETURN v_result;
END;
$function$;
