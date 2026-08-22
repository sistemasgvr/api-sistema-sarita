DROP FUNCTION IF EXISTS gen_listar_documentos_vencimiento(INTEGER, VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION gen_listar_documentos_vencimiento(
    p_solo_activos INT DEFAULT NULL,
    p_buscar VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_categoria INTEGER DEFAULT NULL,
    p_id_vehiculo INTEGER DEFAULT NULL,
    p_id_sucursal INTEGER DEFAULT NULL,
    p_estado VARCHAR DEFAULT NULL,
    p_dias_alerta INTEGER DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
    v_hoy DATE;
    v_dias_alerta INTEGER;
    v_estado VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_hoy := CURRENT_DATE;
    v_dias_alerta := GREATEST(COALESCE(p_dias_alerta, 30), 0);
    v_estado := NULLIF(TRIM(UPPER(COALESCE(p_estado, ''))), '');
    WITH base AS (
        SELECT
            dv.*,
            CASE
                WHEN dv.fecha_vencimiento < v_hoy THEN 'VENCIDO'
                WHEN dv.fecha_vencimiento <= v_hoy + (v_dias_alerta || ' days')::interval THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_calculado,
            (dv.fecha_vencimiento - v_hoy) AS dias_para_vencer
        FROM gen_documento_vencimiento dv
        WHERE (p_solo_activos IS NULL OR dv.estado = p_solo_activos)
          AND (p_id_categoria IS NULL OR dv.id_categoria = p_id_categoria)
          AND (p_id_vehiculo IS NULL OR dv.id_vehiculo = p_id_vehiculo)
          AND (p_id_sucursal IS NULL OR dv.id_sucursal = p_id_sucursal)
          AND (
              p_buscar = ''
              OR gen_texto_coincide(COALESCE(dv.descripcion, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(dv.numero_documento, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(dv.observacion, ''), p_buscar)
          )
    ),
    filtrado AS (
        SELECT * FROM base
        WHERE v_estado IS NULL OR estado_calculado = v_estado
    )
    SELECT json_build_object(
        'total', (SELECT COUNT(*) FROM filtrado),
        'resumen', json_build_object(
            'vigentes', (SELECT COUNT(*) FROM base WHERE estado_calculado = 'VIGENTE'),
            'porVencer', (SELECT COUNT(*) FROM base WHERE estado_calculado = 'POR_VENCER'),
            'vencidos', (SELECT COUNT(*) FROM base WHERE estado_calculado = 'VENCIDO')
        ),
        'registros', COALESCE((
            SELECT json_agg(row_to_json(p) ORDER BY p.fecha_vencimiento ASC, p.id ASC)
            FROM (
                SELECT
                    f.id,
                    f.id_categoria,
                    cat.nombre AS nombre_categoria,
                    f.descripcion,
                    f.id_vehiculo,
                    veh.placa AS vehiculo_placa,
                    veh.marca AS vehiculo_marca,
                    veh.modelo AS vehiculo_modelo,
                    f.id_sucursal,
                    suc.nombre AS sucursal_nombre,
                    f.fecha_vencimiento,
                    f.fecha_renovacion,
                    f.numero_documento,
                    f.observacion,
                    f.id_estado,
                    f.estado_calculado,
                    f.dias_para_vencer,
                    f.estado,
                    f.fecha_creacion,
                    f.fecha_modificacion,
                    f.id_usuario_creacion,
                    uc.nombre AS nombre_usuario_creacion,
                    f.id_usuario_modificacion,
                    um.nombre AS nombre_usuario_modificacion
                FROM filtrado f
                LEFT JOIN gen_lista_opciones cat ON f.id_categoria = cat.id
                LEFT JOIN gen_vehiculo veh ON f.id_vehiculo = veh.id
                LEFT JOIN gen_sucursal suc ON f.id_sucursal = suc.id
                LEFT JOIN auth_usuarios uc ON f.id_usuario_creacion = uc.id
                LEFT JOIN auth_usuarios um ON f.id_usuario_modificacion = um.id
                ORDER BY f.fecha_vencimiento ASC, f.id ASC
                LIMIT p_limite
                OFFSET p_offset
            ) p
        ), '[]'::json)
    )
    INTO v_result;
    RETURN v_result;
END;
$function$;
