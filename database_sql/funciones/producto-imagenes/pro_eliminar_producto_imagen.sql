CREATE OR REPLACE FUNCTION pro_eliminar_producto_imagen(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto INTEGER;
    v_id_archivo INTEGER;
    v_ruta VARCHAR;
    v_bucket VARCHAR;
    v_promover_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pi.id_producto,
        pi.id_archivo,
        a.ruta,
        a.bucket
    INTO
        v_id_producto,
        v_id_archivo,
        v_ruta,
        v_bucket
    FROM pro_producto_imagen pi
    INNER JOIN gen_archivo a ON pi.id_archivo = a.id
    WHERE pi.id = p_id AND pi.estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE pro_producto_imagen
    SET estado = 0,
        es_principal = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- Si no queda principal, promover la de menor orden
    IF NOT EXISTS (
        SELECT 1 FROM pro_producto_imagen
        WHERE id_producto = v_id_producto AND estado = 1 AND es_principal = TRUE
    ) THEN
        SELECT id INTO v_promover_id
        FROM pro_producto_imagen
        WHERE id_producto = v_id_producto AND estado = 1
        ORDER BY orden ASC, id ASC
        LIMIT 1;

        IF v_promover_id IS NOT NULL THEN
            UPDATE pro_producto_imagen
            SET es_principal = TRUE,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_promover_id;
        END IF;
    END IF;

    RETURN json_build_object(
        'eliminado', TRUE,
        'id', p_id,
        'id_producto', v_id_producto,
        'id_archivo', v_id_archivo,
        'ruta', v_ruta,
        'bucket', v_bucket
    );
END;
$function$;
