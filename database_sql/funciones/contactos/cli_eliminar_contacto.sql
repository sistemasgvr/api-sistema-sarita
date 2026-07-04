DROP FUNCTION IF EXISTS cli_eliminar_contacto(INT, INT);

CREATE OR REPLACE FUNCTION cli_eliminar_contacto(
    p_id         INT,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM cli_contacto WHERE id = p_id) THEN
        RETURN json_build_object('error', 'El contacto no existe', 'registro', NULL);
    END IF;

    UPDATE cli_contacto
    SET 
        estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('error', NULL, 'mensaje', 'Contacto eliminado correctamente');
END;
$$;