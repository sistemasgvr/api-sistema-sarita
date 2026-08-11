CREATE OR REPLACE FUNCTION fin_eliminar_caja_observacion(
    p_id INT,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';
    UPDATE fin_caja_observacion
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Observación no encontrada', 'eliminado', false);
    END IF;
    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;
