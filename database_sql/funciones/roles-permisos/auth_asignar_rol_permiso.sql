CREATE OR REPLACE FUNCTION auth_asignar_rol_permiso(
    p_id_rol INTEGER,
    p_id_permiso INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM auth_roles_permisos
        WHERE id_rol = p_id_rol AND id_permiso = p_id_permiso AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El rol ya tiene asignado este permiso', 'registro', NULL);
    END IF;

    UPDATE auth_roles_permisos
    SET estado = TRUE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_rol = p_id_rol AND id_permiso = p_id_permiso
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        INSERT INTO auth_roles_permisos (id_rol, id_permiso, id_usuario_creacion, id_usuario_modificacion)
        VALUES (p_id_rol, p_id_permiso, p_id_usuario_auditoria, p_id_usuario_auditoria)
        RETURNING id INTO v_id;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT rp.*, r.nombre AS nombre_rol, p.nombre AS nombre_permiso
        FROM auth_roles_permisos rp
        INNER JOIN auth_roles r ON rp.id_rol = r.id
        INNER JOIN auth_permisos p ON rp.id_permiso = p.id
        WHERE rp.id = v_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
