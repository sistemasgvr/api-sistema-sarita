CREATE OR REPLACE FUNCTION gen_obtener_condicion_pago(p_id INTEGER)
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
            cp.id,
            cp.codigo,
            cp.nombre,
            cp.dias_credito,
            cp.estado,
            cp.fecha_creacion,
            cp.fecha_modificacion,
            cp.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cp.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_condicion_pago cp
        LEFT JOIN auth_usuarios uc ON cp.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cp.id_usuario_modificacion = um.id
        WHERE cp.id = p_id AND cp.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
