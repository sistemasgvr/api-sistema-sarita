CREATE OR REPLACE FUNCTION bal_actualizar_alquiler_detalle(
    p_id INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_alquiler INTO v_id_alquiler
    FROM bal_alquiler_detalle
    WHERE id = p_id AND estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_alquiler_detalle
        WHERE id_alquiler = v_id_alquiler AND id_balon = p_id_balon AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
    END IF;

    UPDATE bal_alquiler_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$;
