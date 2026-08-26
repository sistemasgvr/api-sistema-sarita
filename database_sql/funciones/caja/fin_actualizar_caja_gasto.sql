DROP FUNCTION IF EXISTS fin_actualizar_caja_gasto(INT, VARCHAR, NUMERIC, INT, INT, VARCHAR, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_actualizar_caja_gasto(
    p_id INT,
    p_concepto VARCHAR,
    p_monto NUMERIC,
    p_id_medio_pago INT DEFAULT NULL,
    p_id_categoria_gasto INT DEFAULT NULL,
    p_numero_operacion VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_fecha DATE;
    v_id_sesion INT;
    v_estado VARCHAR;
    v_err TEXT;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NULLIF(TRIM(p_concepto), '') IS NULL OR COALESCE(p_monto, 0) <= 0 THEN
        RETURN json_build_object('error', 'Concepto y monto (> 0) son obligatorios', 'registro', NULL);
    END IF;

    SELECT g.fecha, g.id_sesion
    INTO v_fecha, v_id_sesion
    FROM fin_caja_gasto g
    WHERE g.id = p_id AND g.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Gasto no encontrado', 'registro', NULL);
    END IF;
    IF v_id_sesion IS NOT NULL THEN
        SELECT UPPER(est.nombre) INTO v_estado
        FROM fin_caja_sesion s
        INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id_sesion AND s.estado = 1;

        IF v_estado IS DISTINCT FROM 'ABIERTA' THEN
            RETURN json_build_object(
                'error',
                'Solo se puede editar un gasto mientras la caja esté abierta. Si ya cerró, no se modifica el arqueo.',
                'registro',
                NULL
            );
        END IF;
    ELSE
        v_err := fin_caja_assert_abierta(v_fecha, NULL);
        IF v_err IS NOT NULL THEN
            RETURN json_build_object('error', v_err, 'registro', NULL);
        END IF;
    END IF;

    UPDATE fin_caja_gasto
    SET concepto = TRIM(p_concepto),
        monto = p_monto,
        id_medio_pago = p_id_medio_pago,
        id_categoria_gasto = p_id_categoria_gasto,
        numero_operacion = NULLIF(TRIM(p_numero_operacion), ''),
        observacion = NULLIF(TRIM(p_observacion), ''),
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id, g.fecha, g.concepto, g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_categoria_gasto AS "idCategoriaGasto",
            cat.nombre AS "categoriaGasto",
            g.numero_operacion AS "numeroOperacion",
            g.observacion,
            g.id_sesion AS "idSesion"
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones cat ON cat.id = g.id_categoria_gasto
        WHERE g.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
