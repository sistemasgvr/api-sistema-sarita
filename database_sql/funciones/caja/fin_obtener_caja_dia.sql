CREATE OR REPLACE FUNCTION fin_obtener_caja_dia(
    p_fecha DATE,
    p_id_sucursal INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sesion_id INT;
    v_totales JSON;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    SELECT s.id INTO v_sesion_id
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    v_totales := fin_caja_calcular_totales(p_fecha, p_id_sucursal);

    IF v_sesion_id IS NOT NULL THEN
        RETURN fin_obtener_caja_sesion(v_sesion_id);
    END IF;

    SELECT json_build_object(
        'id', NULL,
        'fecha', p_fecha,
        'idSucursal', p_id_sucursal,
        'estadoCaja', NULL,
        'montoInicial', 0,
        'totales', v_totales,
        'cajaEsperada',
            COALESCE((v_totales->>'ventasMediosCaja')::NUMERIC, 0)
            + COALESCE((v_totales->>'cobranzasMediosCaja')::NUMERIC, 0)
            + COALESCE((v_totales->>'garantiasCobroMediosCaja')::NUMERIC, 0)
            - COALESCE((v_totales->>'depositos')::NUMERIC, 0)
            - COALESCE((v_totales->>'gastosCaja')::NUMERIC, 0)
            - COALESCE((v_totales->>'garantiasDevolucionMediosCaja')::NUMERIC, 0)
    ) INTO v_registro;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
