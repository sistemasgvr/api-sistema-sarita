CREATE OR REPLACE FUNCTION auth_listar_ids_usuarios_por_roles(
    p_ids_roles JSON DEFAULT '[]'::JSON
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_ids JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(DISTINCT u.id ORDER BY u.id), '[]'::JSON)
    INTO v_ids
    FROM auth_usuarios u
    INNER JOIN auth_usuarios_roles ur ON ur.id_usuario = u.id AND ur.estado = TRUE
    INNER JOIN auth_roles r ON r.id = ur.id_rol AND r.estado = TRUE
    WHERE u.estado = TRUE
      AND r.id IN (
          SELECT (value)::INTEGER
          FROM json_array_elements_text(COALESCE(p_ids_roles, '[]'::JSON))
          WHERE TRIM(value) ~ '^[0-9]+$'
      );

    RETURN json_build_object('ids', v_ids);
END;
$function$;
