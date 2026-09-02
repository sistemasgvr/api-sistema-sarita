-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_bajas_solicitadas
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.644Z
DROP FUNCTION IF EXISTS dash_balones_bajas_solicitadas();

CREATE OR REPLACE FUNCTION dash_balones_bajas_solicitadas()
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result JSON;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(
      json_build_object(
        'idBaja', bb.id,
        'idBalon', b.id,
        'codigoBalon', b.codigo_balon,
        'motivo', mb.nombre,
        'motivoDetalle', bb.motivo_detalle,
        'fechaBaja', bb.fecha_baja,
        'usuarioSolicita', us.nombre
      )
      ORDER BY bb.fecha_baja
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_baja_balon bb
  JOIN bal_balon b ON b.id = bb.id_balon
  LEFT JOIN gen_lista_opciones mb ON mb.id = bb.id_motivo_baja
  LEFT JOIN auth_usuarios us ON us.id = bb.id_usuario_solicita
  WHERE bb.estado = 1
    AND bb.estado_aprobacion = 'PENDIENTE';

  RETURN v_result;
END;
$function$
