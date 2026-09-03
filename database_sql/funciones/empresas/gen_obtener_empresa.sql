-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_empresa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS gen_obtener_empresa(p_id integer);

CREATE OR REPLACE FUNCTION gen_obtener_empresa(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            e.id,
            e.ruc,
            e.razon_social,
            e.nombre_comercial,
            e.direccion,
            e.telefono,
            e.email,
            e.tolerancia_m3_ruta_pueblo,
            e.psi_minimo_util,
            e.estado,
            e.fecha_creacion,
            e.fecha_modificacion,
            e.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            e.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_empresa e
        LEFT JOIN auth_usuarios uc ON e.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON e.id_usuario_modificacion = um.id
        WHERE e.id = p_id AND e.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
