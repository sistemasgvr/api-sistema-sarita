CREATE OR REPLACE FUNCTION pro_actualizar_producto_imagen(
    p_id INTEGER,
    p_orden INTEGER DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT NULL,
    p_id_archivo INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_producto INTO v_id_producto
    FROM pro_producto_imagen
    WHERE id = p_id AND estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_archivo IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM gen_archivo WHERE id = p_id_archivo AND estado = 1) THEN
        RETURN json_build_object('error', 'Archivo no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF p_es_principal = TRUE THEN
        UPDATE pro_producto_imagen
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_producto = v_id_producto
          AND estado = 1
          AND id <> p_id
          AND es_principal = TRUE;
    END IF;

    UPDATE pro_producto_imagen
    SET
        orden = COALESCE(p_orden, orden),
        es_principal = COALESCE(p_es_principal, es_principal),
        id_archivo = COALESCE(p_id_archivo, id_archivo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN pro_obtener_producto_imagen(p_id);
END;
$function$;
