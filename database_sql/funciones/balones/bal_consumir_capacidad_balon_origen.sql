-- Resta capacidad del balón empresa origen. Si residual <= 0 → VACIO.
CREATE OR REPLACE FUNCTION bal_consumir_capacidad_balon_origen(
    p_id_balon INTEGER,
    p_cantidad NUMERIC,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_disponible NUMERIC;
    v_nuevo NUMERIC;
    v_id_vacio INTEGER;
BEGIN
    IF p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'El balón origen es obligatorio');
    END IF;

    IF COALESCE(p_cantidad, 0) <= 0 THEN
        RETURN json_build_object('error', 'La cantidad a consumir debe ser mayor a cero');
    END IF;

    v_disponible := bal_capacidad_disponible_balon(p_id_balon);

    IF v_disponible < p_cantidad THEN
        RETURN json_build_object(
            'error',
            format(
                'El balón origen no tiene capacidad suficiente (disponible: %s, requerido: %s)',
                v_disponible,
                p_cantidad
            )
        );
    END IF;

    v_nuevo := v_disponible - p_cantidad;
    v_id_vacio := bal_id_estado_contenido('VACIO');

    IF v_nuevo <= 0 THEN
        UPDATE bal_balon
        SET
            capacidad_restante = 0,
            id_estado_contenido = COALESCE(v_id_vacio, id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    ELSE
        UPDATE bal_balon
        SET
            capacidad_restante = v_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'No se pudo actualizar el balón origen');
    END IF;

    RETURN json_build_object(
        'ok', TRUE,
        'capacidad_restante', GREATEST(v_nuevo, 0),
        'quedo_vacio', v_nuevo <= 0
    );
END;
$function$;
