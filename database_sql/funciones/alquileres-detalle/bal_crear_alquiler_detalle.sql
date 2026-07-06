CREATE OR REPLACE FUNCTION bal_crear_alquiler_detalle(
    p_id_alquiler INTEGER,
    p_id_balon INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El alquiler indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler_detalle
        WHERE id_alquiler = p_id_alquiler AND id_balon = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
    END IF;

    INSERT INTO bal_alquiler_detalle (
        id_alquiler, id_balon,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_alquiler, p_id_balon,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_alquiler_detalle(v_id);
END;
$function$;
