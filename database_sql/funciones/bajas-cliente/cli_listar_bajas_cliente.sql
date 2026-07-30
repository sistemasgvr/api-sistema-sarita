DROP FUNCTION IF EXISTS cli_listar_bajas_cliente;

CREATE OR REPLACE FUNCTION cli_listar_bajas_cliente(
    p_solo_activos INT DEFAULT NULL,
    p_buscar VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_estado_aprobacion INTEGER DEFAULT NULL,
    p_id_tipo_solicitud INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM cli_baja_cliente bc
    WHERE (p_solo_activos IS NULL OR bc.estado = p_solo_activos)
      AND (p_id_cliente IS NULL OR bc.id_cliente = p_id_cliente)
      AND (p_id_estado_aprobacion IS NULL OR bc.id_estado_aprobacion = p_id_estado_aprobacion)
      AND (p_id_tipo_solicitud IS NULL OR bc.id_tipo_solicitud = p_id_tipo_solicitud)
      AND (
          p_buscar = ''
          OR LOWER(COALESCE(bc.motivo_detalle, '')) LIKE LOWER('%' || p_buscar || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            bc.id,
            bc.id_tipo_solicitud,
            ts.nombre AS nombre_tipo_solicitud,
            bc.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            bc.id_motivo_baja,
            mb.nombre AS nombre_motivo_baja,
            bc.fecha_baja,
            bc.id_usuario_solicita,
            us.nombre AS nombre_usuario_solicita,
            bc.id_usuario_autoriza,
            ua.nombre AS nombre_usuario_autoriza,
            bc.fecha_autorizacion,
            bc.id_estado_aprobacion,
            ea.nombre AS nombre_estado_aprobacion,
            bc.motivo_detalle,
            bc.estado,
            bc.fecha_creacion,
            bc.fecha_modificacion,
            bc.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            bc.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM cli_baja_cliente bc
        INNER JOIN cli_clientes c ON bc.id_cliente = c.id
        LEFT JOIN gen_lista_opciones ts ON bc.id_tipo_solicitud = ts.id
        LEFT JOIN gen_lista_opciones mb ON bc.id_motivo_baja = mb.id
        LEFT JOIN gen_lista_opciones ea ON bc.id_estado_aprobacion = ea.id
        LEFT JOIN auth_usuarios us ON bc.id_usuario_solicita = us.id
        LEFT JOIN auth_usuarios ua ON bc.id_usuario_autoriza = ua.id
        LEFT JOIN auth_usuarios uc ON bc.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON bc.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR bc.estado = p_solo_activos)
          AND (p_id_cliente IS NULL OR bc.id_cliente = p_id_cliente)
          AND (p_id_estado_aprobacion IS NULL OR bc.id_estado_aprobacion = p_id_estado_aprobacion)
          AND (p_id_tipo_solicitud IS NULL OR bc.id_tipo_solicitud = p_id_tipo_solicitud)
          AND (
              p_buscar = ''
              OR LOWER(COALESCE(bc.motivo_detalle, '')) LIKE LOWER('%' || p_buscar || '%')
          )
        ORDER BY bc.fecha_creacion DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
