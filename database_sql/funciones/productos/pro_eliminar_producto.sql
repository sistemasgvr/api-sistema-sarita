-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_eliminar_producto
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS pro_eliminar_producto(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_eliminar_producto(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM pro_stock
        WHERE id_producto = p_id AND estado = 1 AND stock <> 0
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el producto porque tiene stock distinto de cero'
        );
    END IF;

    UPDATE pro_producto
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Las imágenes y archivos en storage se conservan para poder restaurar el producto
    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
