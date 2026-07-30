CREATE OR REPLACE FUNCTION gen_eliminar_archivo_por_ruta(
    p_bucket VARCHAR,
    p_ruta VARCHAR,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_archivo
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE bucket = p_bucket
      AND ruta = p_ruta
      AND estado = 1
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', NULL);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', v_id);
END;
$function$;
