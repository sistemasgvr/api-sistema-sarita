-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_documento_vencimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.748Z
DROP FUNCTION IF EXISTS gen_obtener_documento_vencimiento(p_id integer);

CREATE OR REPLACE FUNCTION gen_obtener_documento_vencimiento(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_hoy DATE;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_hoy := CURRENT_DATE;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            dv.id,
            dv.id_categoria,
            cat.nombre AS nombre_categoria,
            cat.descripcion AS descripcion_categoria,
            dv.descripcion,
            dv.id_vehiculo,
            v.placa AS vehiculo_placa,
            v.marca AS vehiculo_marca,
            v.modelo AS vehiculo_modelo,
            dv.id_sucursal,
            suc.nombre AS sucursal_nombre,
            dv.fecha_vencimiento,
            dv.fecha_renovacion,
            dv.numero_documento,
            dv.observacion,
            dv.id_estado,
            -- Estado SIEMPRE calculado a partir de fecha_vencimiento (no de la columna
            -- id_estado, que es manual y se desactualiza). Umbral "por vencer": 30 días.
            CASE
                WHEN dv.fecha_vencimiento < v_hoy THEN 'VENCIDO'
                WHEN dv.fecha_vencimiento <= v_hoy + INTERVAL '30 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_calculado,
            (dv.fecha_vencimiento - v_hoy) AS dias_para_vencer,
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
        LEFT JOIN gen_sucursal suc ON dv.id_sucursal = suc.id
        LEFT JOIN auth_usuarios uc ON dv.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON dv.id_usuario_modificacion = um.id
        WHERE dv.id = p_id AND dv.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
