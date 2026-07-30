CREATE OR REPLACE FUNCTION pro_crear_producto_imagen(
    p_id_producto INTEGER,
    p_id_archivo INTEGER,
    p_orden INTEGER DEFAULT NULL,
    p_es_principal BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_orden INTEGER;
    v_es_principal BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'El id_producto es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
        RETURN json_build_object('error', 'Producto no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF p_id_archivo IS NULL THEN
        RETURN json_build_object('error', 'El id_archivo es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_archivo WHERE id = p_id_archivo AND estado = 1) THEN
        RETURN json_build_object('error', 'Archivo no encontrado o inactivo', 'registro', NULL);
    END IF;

    IF p_orden IS NULL THEN
        SELECT COALESCE(MAX(orden), -1) + 1 INTO v_orden
        FROM pro_producto_imagen
        WHERE id_producto = p_id_producto AND estado = 1;
    ELSE
        v_orden := p_orden;
    END IF;

    v_es_principal := COALESCE(p_es_principal, FALSE);

    -- Si es la primera imagen del producto, marcarla como principal
    IF v_es_principal = FALSE
       AND NOT EXISTS (
           SELECT 1 FROM pro_producto_imagen
           WHERE id_producto = p_id_producto AND estado = 1
       ) THEN
        v_es_principal := TRUE;
    END IF;

    IF v_es_principal = TRUE THEN
        UPDATE pro_producto_imagen
        SET es_principal = FALSE,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_producto = p_id_producto
          AND estado = 1
          AND es_principal = TRUE;
    END IF;

    INSERT INTO pro_producto_imagen (
        id_producto,
        id_archivo,
        orden,
        es_principal,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_producto,
        p_id_archivo,
        v_orden,
        v_es_principal,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_producto_imagen(v_id);
END;
$function$;
