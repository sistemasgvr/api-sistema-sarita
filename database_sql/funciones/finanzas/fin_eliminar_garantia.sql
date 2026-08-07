-- Baja lógica de una garantía.

DROP FUNCTION IF EXISTS fin_eliminar_garantia(INT, INT);

CREATE OR REPLACE FUNCTION fin_eliminar_garantia(
    p_id         INT,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE fin_garantia
       SET estado = 0,
           id_usuario_modificacion = p_id_usuario,
           fecha_modificacion = NOW()
     WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', false, 'id', p_id, 'error', 'La garantía no existe o ya está inactiva');
    END IF;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$$;
