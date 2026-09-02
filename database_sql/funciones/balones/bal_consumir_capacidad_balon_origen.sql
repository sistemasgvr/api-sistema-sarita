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

    v_nuevo := GREATEST(v_disponible - p_cantidad, 0);

    RETURN json_build_object(
        'ok', TRUE,
        'consumido', p_cantidad,
        'quedo_vacio', v_nuevo <= 0
    );
END;
$function$;
