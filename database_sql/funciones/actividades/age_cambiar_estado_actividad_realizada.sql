DROP FUNCTION IF EXISTS age_cambiar_estado_actividad_realizada;

CREATE OR REPLACE FUNCTION age_cambiar_estado_actividad_realizada(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_realizada INTEGER;
    v_id_estado_actual INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id INTO v_id_estado_realizada
    FROM gen_lista_opciones
    WHERE LOWER(nombre) = 'realizada';

    IF v_id_estado_realizada IS NULL THEN
        RAISE EXCEPTION 'No se encontró el estado REALIZADA en la lista de opciones (gen_lista_opciones).';
    END IF;

    SELECT id_estado_actividad INTO v_id_estado_actual
    FROM age_actividad
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_id_estado_actual = v_id_estado_realizada THEN
        RAISE EXCEPTION 'La actividad ya se encuentra marcada como realizada.';
    END IF;

    UPDATE age_actividad
    SET 
        id_estado_actividad = v_id_estado_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;