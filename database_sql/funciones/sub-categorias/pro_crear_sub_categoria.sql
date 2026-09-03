-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_crear_sub_categoria
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS pro_crear_sub_categoria(p_id_categoria integer, p_nombre character varying, p_descripcion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_crear_sub_categoria(p_id_categoria integer, p_nombre character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre de la subcategoría es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_categoria WHERE id = p_id_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La categoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_sub_categoria
        WHERE estado = 1
          AND id_categoria = p_id_categoria
          AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
    ) THEN
        RETURN json_build_object('error', 'Ya existe una subcategoría activa con el nombre ' || TRIM(p_nombre) || ' en esta categoría', 'registro', NULL);
    END IF;

    INSERT INTO pro_sub_categoria (
        id_categoria,
        nombre,
        descripcion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_categoria,
        TRIM(p_nombre),
        p_descripcion,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_sub_categoria(v_id);
END;
$function$;
