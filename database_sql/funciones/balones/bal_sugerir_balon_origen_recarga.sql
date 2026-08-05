-- Sugiere el balón empresa origen más antiguo (FIFO) con residual suficiente.
CREATE OR REPLACE FUNCTION bal_sugerir_balon_origen_recarga(
    p_id_producto_gas INTEGER,
    p_capacidad_requerida NUMERIC DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_listado JSON;
    v_registro JSON;
BEGIN
    v_listado := bal_listar_balones_origen_recarga(
        p_id_producto_gas,
        p_capacidad_requerida,
        p_id_almacen,
        1,
        0
    );

    IF v_listado->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_listado->>'error', 'registro', NULL);
    END IF;

    IF COALESCE((v_listado->>'total')::BIGINT, 0) = 0 THEN
        RETURN json_build_object(
            'error',
            'No hay balón empresa LLENO del mismo gas con capacidad suficiente en almacén',
            'registro',
            NULL
        );
    END IF;

    v_registro := (v_listado->'registros')->0;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
