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
    v_sync JSON;
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

    v_sync := bal_sync_capacidad_restante(
        p_id_balon,
        v_nuevo,
        NULL,
        NULL,
        'FROM_M3',
        NULL,
        p_id_usuario_auditoria
    );

    IF COALESCE((v_sync->>'ok')::BOOLEAN, FALSE) IS NOT TRUE THEN
        RETURN json_build_object(
            'error',
            COALESCE(v_sync->>'error', 'No se pudo actualizar el balón origen')
        );
    END IF;

    RETURN json_build_object(
        'ok', TRUE,
        'capacidad_restante', GREATEST(v_nuevo, 0),
        'capacidad_restante_lb', v_sync->'capacidad_restante_lb',
        'quedo_vacio', v_nuevo <= 0
    );
END;
$function$;
