CREATE OR REPLACE FUNCTION fin_crear_caja_gasto(
    p_fecha DATE,
    p_concepto VARCHAR,
    p_monto NUMERIC,
    p_id_medio_pago INT DEFAULT NULL,
    p_id_categoria_gasto INT DEFAULT NULL,
    p_numero_operacion VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_sesion INT DEFAULT NULL,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INT;
    v_registro JSON;
    v_sesion_id INT;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL OR NULLIF(TRIM(p_concepto), '') IS NULL OR COALESCE(p_monto, 0) <= 0 THEN
        RETURN json_build_object('error', 'Fecha, concepto y monto (> 0) son obligatorios', 'registro', NULL);
    END IF;

    v_err_caja := fin_caja_assert_abierta(p_fecha, NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    v_sesion_id := p_id_sesion;
    IF v_sesion_id IS NULL THEN
        SELECT s.id INTO v_sesion_id
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.estado = 1 AND s.fecha = p_fecha AND UPPER(est.nombre) = 'ABIERTA'
        ORDER BY s.id DESC LIMIT 1;
    ELSIF NOT EXISTS (
        SELECT 1
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_sesion_id AND s.estado = 1 AND UPPER(est.nombre) = 'ABIERTA'
    ) THEN
        RETURN json_build_object('error', 'La sesión de caja indicada no está abierta', 'registro', NULL);
    END IF;

    INSERT INTO fin_caja_gasto (
        id_sesion, fecha, concepto, monto, id_medio_pago, id_categoria_gasto,
        numero_operacion, observacion, id_usuario_creacion
    ) VALUES (
        v_sesion_id, p_fecha, TRIM(p_concepto), p_monto, p_id_medio_pago, p_id_categoria_gasto,
        NULLIF(TRIM(p_numero_operacion), ''), NULLIF(TRIM(p_observacion), ''), p_id_usuario
    )
    RETURNING id INTO v_id;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id, g.fecha, g.concepto, g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_categoria_gasto AS "idCategoriaGasto",
            g.numero_operacion AS "numeroOperacion",
            g.observacion,
            g.id_sesion AS "idSesion"
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        WHERE g.id = v_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
