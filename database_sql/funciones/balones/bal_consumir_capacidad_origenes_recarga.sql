-- Consume capacidad de varios balones empresa según asignación FIFO.
CREATE OR REPLACE FUNCTION bal_consumir_capacidad_origenes_recarga(
    p_origenes JSON,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    o JSONB;
    v_consumo JSON;
    v_consumidos JSONB := '[]'::JSONB;
    v_arr JSONB;
BEGIN
    IF p_origenes IS NULL THEN
        RETURN json_build_object('error', 'La asignación de orígenes es obligatoria');
    END IF;

    v_arr := CASE
        WHEN json_typeof(p_origenes) = 'array' THEN p_origenes::JSONB
        ELSE '[]'::JSONB
    END;

    IF jsonb_array_length(v_arr) = 0 THEN
        RETURN json_build_object('error', 'La asignación de orígenes es obligatoria');
    END IF;

    FOR o IN SELECT * FROM jsonb_array_elements(v_arr)
    LOOP
        v_consumo := bal_consumir_capacidad_balon_origen(
            (o->>'id_balon')::INTEGER,
            (o->>'cantidad')::NUMERIC,
            p_id_usuario_auditoria
        );

        IF v_consumo->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_consumo->>'error');
        END IF;

        v_consumidos := v_consumidos || jsonb_build_array(
            jsonb_build_object(
                'id_balon', (o->>'id_balon')::INTEGER,
                'cantidad', (o->>'cantidad')::NUMERIC,
                'capacidad_restante', v_consumo->'capacidad_restante',
                'quedo_vacio', v_consumo->'quedo_vacio'
            )
        );
    END LOOP;

    RETURN json_build_object(
        'ok', TRUE,
        'consumidos', v_consumidos,
        'id_balon_origen_principal', (v_arr->0->>'id_balon')::INTEGER
    );
END;
$function$;
