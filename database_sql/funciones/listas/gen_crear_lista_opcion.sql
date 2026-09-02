-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_lista_opcion
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.710Z
DROP FUNCTION IF EXISTS gen_crear_lista_opcion(p_id_lista integer, p_nombre character varying, p_descripcion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_crear_lista_opcion(p_id_lista integer, p_nombre character varying, p_descripcion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_nombre VARCHAR(150);
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_lista IS NULL THEN
        RETURN json_build_object('error', 'El id_lista es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista WHERE id = p_id_lista AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La lista indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    v_nombre := TRIM(COALESCE(p_nombre, ''));
    IF v_nombre = '' THEN
        RETURN json_build_object('error', 'El nombre de la opción es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM gen_lista_opciones
        WHERE id_lista = p_id_lista
          AND estado = 1
          AND LOWER(TRIM(nombre)) = LOWER(v_nombre)
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe una opción activa con ese nombre en la lista',
            'registro', NULL
        );
    END IF;

    INSERT INTO gen_lista_opciones (
        id_lista,
        nombre,
        descripcion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_lista,
        v_nombre,
        NULLIF(TRIM(COALESCE(p_descripcion, '')), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN json_build_object(
        'error', NULL,
        'registro', (
            SELECT row_to_json(t)
            FROM (
                SELECT
                    lo.id,
                    lo.id_lista,
                    l.nombre AS nombre_lista,
                    lo.nombre,
                    lo.descripcion,
                    lo.estado
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON lo.id_lista = l.id
                WHERE lo.id = v_id
            ) t
        )
    );
END;
$function$
