DROP FUNCTION IF EXISTS pro_crear_traslado_lote(
    DATE, INTEGER, INTEGER, INTEGER, JSONB, VARCHAR, INTEGER, INTEGER, INTEGER
);

CREATE OR REPLACE FUNCTION pro_crear_traslado_lote(
    p_fecha DATE,
    p_id_almacen INTEGER,
    p_id_almacen_destino INTEGER,
    p_id_tipo_movimiento INTEGER,
    p_detalles JSONB,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_documento_ref INTEGER DEFAULT NULL,
    p_id_tipo_documento_ref INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle JSONB;
    v_result JSON;
    v_registros JSONB := '[]'::JSONB;
    v_nombre_tipo VARCHAR;
    v_id_producto INTEGER;
    v_cantidad NUMERIC;
    v_total INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del traslado es obligatoria', 'registros', NULL);
    END IF;

    IF p_detalles IS NULL
       OR jsonb_typeof(p_detalles) <> 'array'
       OR jsonb_array_length(p_detalles) = 0
    THEN
        RETURN json_build_object('error', 'Los detalles del traslado son obligatorios', 'registros', NULL);
    END IF;

    IF p_id_almacen IS NULL OR p_id_almacen_destino IS NULL THEN
        RETURN json_build_object('error', 'Almacén origen y destino son obligatorios', 'registros', NULL);
    END IF;

    IF p_id_almacen = p_id_almacen_destino THEN
        RETURN json_build_object(
            'error', 'El almacén de destino debe ser distinto al de origen',
            'registros', NULL
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén de origen no existe o está inactivo', 'registros', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'registros', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_movimiento AND estado = 1) THEN
        RETURN json_build_object(
            'error', 'El tipo de movimiento indicado no existe o está inactivo',
            'registros', NULL
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_movimiento;

    IF UPPER(COALESCE(v_nombre_tipo, '')) <> 'TRASLADO' THEN
        RETURN json_build_object(
            'error', 'El tipo de movimiento debe ser TRASLADO',
            'registros', NULL
        );
    END IF;

    FOR v_detalle IN SELECT * FROM jsonb_array_elements(p_detalles)
    LOOP
        v_id_producto := NULLIF(TRIM(COALESCE(v_detalle->>'idProducto', '')), '')::INTEGER;
        v_cantidad := NULLIF(TRIM(COALESCE(v_detalle->>'cantidad', '')), '')::NUMERIC;

        IF v_id_producto IS NULL OR v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'Cada detalle debe incluir idProducto y cantidad mayor a cero';
        END IF;

        v_result := pro_crear_movimiento(
            p_fecha,
            v_id_producto,
            p_id_almacen,
            p_id_tipo_movimiento,
            v_cantidad,
            p_id_documento_ref,
            p_id_tipo_documento_ref,
            p_glosa,
            p_id_usuario_auditoria,
            FALSE,
            p_id_almacen_destino
        );

        IF v_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result->>'error';
        END IF;

        v_registros := v_registros || jsonb_build_array(v_result->'registro');
        v_total := v_total + 1;
    END LOOP;

    RETURN json_build_object(
        'error', NULL,
        'registros', v_registros,
        'total', v_total
    );
END;
$function$;
