DROP FUNCTION IF EXISTS act_eliminar_activo_imagen(
    INTEGER,
    INTEGER
);

CREATE OR REPLACE FUNCTION act_eliminar_activo_imagen(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_activo INTEGER;
    v_id_archivo INTEGER;
    v_ruta VARCHAR;
    v_bucket VARCHAR;
    v_promover_id INTEGER;
    v_nueva_ruta VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ai.id_activo,
        ai.id_archivo,
        a.ruta,
        a.bucket
    INTO
        v_id_activo,
        v_id_archivo,
        v_ruta,
        v_bucket
    FROM act_activo_imagen ai
    INNER JOIN gen_archivo a ON ai.id_archivo = a.id
    WHERE ai.id = p_id AND ai.estado = 1;

    IF v_id_activo IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE act_activo_imagen
    SET estado = 0,
        es_principal = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- Si se borró la principal, promover la de menor orden y reflejarla en el activo
    IF NOT EXISTS (
        SELECT 1 FROM act_activo_imagen
        WHERE id_activo = v_id_activo AND estado = 1 AND es_principal = TRUE
    ) THEN
        SELECT id INTO v_promover_id
        FROM act_activo_imagen
        WHERE id_activo = v_id_activo AND estado = 1
        ORDER BY orden ASC, id ASC
        LIMIT 1;

        IF v_promover_id IS NOT NULL THEN
            UPDATE act_activo_imagen
            SET es_principal = TRUE,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_promover_id;

            SELECT a.ruta INTO v_nueva_ruta
            FROM act_activo_imagen ai
            INNER JOIN gen_archivo a ON ai.id_archivo = a.id
            WHERE ai.id = v_promover_id;
        END IF;

        UPDATE act_activos
        SET imagen_principal_ruta = v_nueva_ruta,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_activo;
    END IF;

    RETURN json_build_object(
        'eliminado', TRUE,
        'id', p_id,
        'id_activo', v_id_activo,
        'id_archivo', v_id_archivo,
        'ruta', v_ruta,
        'bucket', v_bucket
    );
END;
$function$;
