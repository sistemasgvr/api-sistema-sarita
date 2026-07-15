DROP FUNCTION IF EXISTS gen_listar_documentos_vencimiento(INTEGER, VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_listar_documentos_vencimiento(
    p_solo_activos INT DEFAULT NULL,
    p_buscar VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_categoria INTEGER DEFAULT NULL,
    p_id_vehiculo INTEGER DEFAULT NULL
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
    FROM gen_documento_vencimiento dv
    WHERE (p_solo_activos IS NULL OR dv.estado = p_solo_activos)
      AND (p_id_categoria IS NULL OR dv.id_categoria = p_id_categoria)
      AND (p_id_vehiculo IS NULL OR dv.id_vehiculo = p_id_vehiculo)
      AND (
          p_buscar = ''
          OR LOWER(COALESCE(dv.descripcion, '')) LIKE LOWER('%' || p_buscar || '%')
          OR LOWER(COALESCE(dv.numero_documento, '')) LIKE LOWER('%' || p_buscar || '%')
          OR LOWER(COALESCE(dv.observacion, '')) LIKE LOWER('%' || p_buscar || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            dv.id,
            dv.id_categoria,
            cat.nombre AS nombre_categoria,
            dv.descripcion,
            dv.id_vehiculo,
            v.placa AS vehiculo_placa,
            v.marca AS vehiculo_marca,
            v.modelo AS vehiculo_modelo,
            dv.fecha_vencimiento,
            dv.fecha_renovacion,
            dv.numero_documento,
            dv.observacion,
            dv.id_estado,
            est.nombre AS nombre_estado,
            dv.estado,
            dv.fecha_creacion,
            dv.fecha_modificacion,
            dv.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            dv.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_documento_vencimiento dv
        LEFT JOIN gen_lista_opciones cat ON dv.id_categoria = cat.id
        LEFT JOIN gen_vehiculo v ON dv.id_vehiculo = v.id
        LEFT JOIN gen_lista_opciones est ON dv.id_estado = est.id
        LEFT JOIN auth_usuarios uc ON dv.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON dv.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR dv.estado = p_solo_activos)
          AND (p_id_categoria IS NULL OR dv.id_categoria = p_id_categoria)
          AND (p_id_vehiculo IS NULL OR dv.id_vehiculo = p_id_vehiculo)
          AND (
              p_buscar = ''
              OR LOWER(COALESCE(dv.descripcion, '')) LIKE LOWER('%' || p_buscar || '%')
              OR LOWER(COALESCE(dv.numero_documento, '')) LIKE LOWER('%' || p_buscar || '%')
              OR LOWER(COALESCE(dv.observacion, '')) LIKE LOWER('%' || p_buscar || '%')
          )
        ORDER BY dv.fecha_vencimiento ASC, dv.id ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
