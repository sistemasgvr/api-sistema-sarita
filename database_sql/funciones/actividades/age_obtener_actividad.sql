DROP FUNCTION IF EXISTS age_obtener_actividad;

CREATE OR REPLACE FUNCTION age_obtener_actividad(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad, 
            pr.nombre AS nombre_prioridad, 
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            act.id_usuario_responsable,
            u.nombre AS nombre_usuario_responsable,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.fecha_creacion,
            act.fecha_modificacion,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta ON act.id_tipo_actividad = ta.id
        LEFT JOIN gen_lista_opciones pr ON act.id_prioridad = pr.id
        LEFT JOIN gen_lista_opciones ea ON act.id_estado_actividad = ea.id
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN auth_usuarios u ON act.id_usuario_responsable = u.id
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;