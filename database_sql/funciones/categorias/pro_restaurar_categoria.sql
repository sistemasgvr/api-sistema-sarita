-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_restaurar_categoria
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS pro_restaurar_categoria(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_restaurar_categoria(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INTEGER;
    v_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado, nombre INTO v_estado, v_nombre
    FROM pro_categoria
    WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_estado = 1 THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pro_categoria
        WHERE id <> p_id
          AND estado = 1
          AND LOWER(TRIM(nombre)) = LOWER(TRIM(v_nombre))
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'Ya existe una categoría activa con el mismo nombre'
        );
    END IF;

    UPDATE pro_categoria
    SET estado = 1,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
