-- Crea una cuenta financiera CON PLAN DE CUOTAS (ej. préstamo bancario a pagar,
-- venta/compra a plazos, servicio pagado en N cuotas, etc.).
--
-- Genera:
--   - 1 fila padre en fin_cuenta con numero_cuotas_total = N y monto_pendiente = monto total.
--   - N filas hijas con numero_cuota = 1..N, monto a 2 decimales (última cuota
--     absorbe el céntimo de redondeo, ej. 1000 / 3 = 333.33 + 333.33 + 333.34).
--
-- Recurrencia MENSUAL:
--   - Cuota 1: fecha exacta que envía el usuario en p_fecha_primera_cuota.
--   - Cuota i (i>=2): mes (mes_primera + i-1), día = p_dia_mes_pago.
--     Si el mes destino no tiene ese día (ej. día 31 en febrero), se ajusta al
--     ÚLTIMO DÍA del mes (28/29/30 según corresponda).
--
-- Los pagos posteriores (fin_pago) se aplican a las CUOTAS HIJAS.

DROP FUNCTION IF EXISTS fin_crear_cuenta_cuotas(
  VARCHAR, INT, VARCHAR, DATE, NUMERIC, INT, INT, DATE, VARCHAR, VARCHAR, INT, NUMERIC, INT
);
DROP FUNCTION IF EXISTS fin_crear_cuenta_cuotas(
  VARCHAR, INT, VARCHAR, DATE, NUMERIC, INT, DATE, INT, VARCHAR, VARCHAR, INT, NUMERIC, INT
);
DROP FUNCTION IF EXISTS fin_crear_cuenta_cuotas(
  VARCHAR, INT, VARCHAR, DATE, NUMERIC, INT, DATE, INT, VARCHAR, VARCHAR, INT, NUMERIC, VARCHAR, INT
);
DROP FUNCTION IF EXISTS fin_crear_cuenta_cuotas(
  VARCHAR, INT, VARCHAR, DATE, NUMERIC, INT, DATE, INT, VARCHAR, VARCHAR, INT, NUMERIC, VARCHAR, INT, INT
);
DROP FUNCTION IF EXISTS fin_crear_cuenta_cuotas(
  VARCHAR, INT, VARCHAR, DATE, NUMERIC, INT, DATE, INT, VARCHAR, VARCHAR, INT, NUMERIC, VARCHAR, INT, INT, INT
);

CREATE OR REPLACE FUNCTION fin_crear_cuenta_cuotas(
    p_tipo                 VARCHAR,
    p_id_tercero           INT     DEFAULT NULL,
    p_tercero_nombre       VARCHAR DEFAULT NULL,
    p_fecha_emision        DATE    DEFAULT NULL,
    p_monto_total          NUMERIC DEFAULT NULL,
    p_numero_cuotas        INT     DEFAULT NULL,
    p_fecha_primera_cuota  DATE    DEFAULT NULL,   -- fecha exacta de la cuota #1
    p_dia_mes_pago         INT     DEFAULT NULL,   -- 1..31; día del mes para cuotas #2..N
    p_descripcion          VARCHAR DEFAULT NULL,
    p_observacion          VARCHAR DEFAULT NULL,
    p_id_banco             INT     DEFAULT NULL,
    p_tasa_interes         NUMERIC DEFAULT NULL,
    p_numero_comprobante   VARCHAR DEFAULT NULL,
    p_id_usuario           INT     DEFAULT NULL,
    p_id_comprobante_venta INT     DEFAULT NULL,
    p_id_comprobante_compra INT    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo         INT;
    v_id_tercero      INT;
    v_nombre          VARCHAR;
    v_id_padre        INT;
    v_monto_total     NUMERIC(12,2);
    v_monto_cuota     NUMERIC(12,2);
    v_ultima_cuota    NUMERIC(12,2);
    v_fecha_cuota     DATE;
    v_mes_base        DATE;
    v_ultimo_dia_mes  DATE;
    v_i               INT;
    v_registro        JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = UPPER(COALESCE(p_tipo, ''))
    LIMIT 1;

    IF v_id_tipo IS NULL THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', format(
                'Tipo de cuenta inválido. Recibido: %L. Opciones existentes en TipoCuentaFinanciera: [%s].',
                p_tipo,
                COALESCE((
                    SELECT string_agg(glo.nombre, ', ')
                    FROM gen_lista_opciones glo
                    JOIN gen_lista gl ON gl.id = glo.id_lista
                    WHERE gl.nombre = 'TipoCuentaFinanciera'
                ), 'vacío')
            )
        );
    END IF;

    v_nombre := NULLIF(TRIM(p_tercero_nombre), '');
    IF p_id_tercero IS NULL AND v_nombre IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el tercero o su nombre');
    END IF;

    IF p_id_tercero IS NOT NULL THEN
        SELECT id INTO v_id_tercero FROM cli_clientes WHERE id = p_id_tercero AND estado = 1;
        IF v_id_tercero IS NULL THEN
            RETURN json_build_object('registro', NULL, 'error', 'El tercero no existe o está inactivo');
        END IF;
    END IF;

    IF p_fecha_emision IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha de emisión es obligatoria');
    END IF;

    IF p_fecha_primera_cuota IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha de la primera cuota es obligatoria');
    END IF;

    IF p_fecha_primera_cuota < p_fecha_emision THEN
        RETURN json_build_object('registro', NULL, 'error', 'La primera cuota no puede ser anterior a la emisión');
    END IF;

    IF p_monto_total IS NULL OR p_monto_total <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto total debe ser mayor a cero');
    END IF;

    IF p_numero_cuotas IS NULL OR p_numero_cuotas < 1 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El número de cuotas debe ser al menos 1');
    END IF;

    IF p_dia_mes_pago IS NULL OR p_dia_mes_pago < 1 OR p_dia_mes_pago > 31 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El día del mes de pago debe estar entre 1 y 31');
    END IF;

    v_monto_total  := fin_redondear_monto(p_monto_total);
    v_monto_cuota  := ROUND(v_monto_total / p_numero_cuotas, 2);
    v_ultima_cuota := v_monto_total - (v_monto_cuota * (p_numero_cuotas - 1));

    -- Cabecera
    INSERT INTO fin_cuenta (
        id_tipo_cuenta, id_tercero, tercero_nombre,
        id_comprobante_venta, id_comprobante_compra,
        fecha_emision, fecha_vencimiento,
        monto_pendiente, monto_abonado, monto_saldo,
        numero_cuotas_total,
        descripcion, observacion,
        id_banco, tasa_interes,
        numero_comprobante,
        id_usuario_creacion,
        id_usuario_modificacion
    ) VALUES (
        v_id_tipo, v_id_tercero, v_nombre,
        p_id_comprobante_venta, p_id_comprobante_compra,
        p_fecha_emision, NULL,
        v_monto_total, 0, v_monto_total,
        p_numero_cuotas,
        NULLIF(TRIM(p_descripcion), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_banco, p_tasa_interes,
        NULLIF(TRIM(p_numero_comprobante), ''),
        p_id_usuario,
        p_id_usuario
    )
    RETURNING id INTO v_id_padre;

    -- Cuotas hijas
    FOR v_i IN 1..p_numero_cuotas LOOP
        IF v_i = 1 THEN
            v_fecha_cuota := p_fecha_primera_cuota;
        ELSE
            v_mes_base := date_trunc('month', p_fecha_primera_cuota)::date
                          + ((v_i - 1) * INTERVAL '1 month');
            v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
            v_fecha_cuota := LEAST(
                (v_mes_base + ((p_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                v_ultimo_dia_mes
            );
        END IF;

        INSERT INTO fin_cuenta (
            id_tipo_cuenta, id_tercero, tercero_nombre,
            id_comprobante_venta, id_comprobante_compra,
            id_cuenta_padre, numero_cuota,
            fecha_emision, fecha_vencimiento,
            monto_pendiente, monto_abonado, monto_saldo,
            descripcion,
            id_usuario_creacion,
            id_usuario_modificacion
        ) VALUES (
            v_id_tipo, v_id_tercero, v_nombre,
            p_id_comprobante_venta, p_id_comprobante_compra,
            v_id_padre, v_i,
            p_fecha_emision, v_fecha_cuota,
            CASE WHEN v_i = p_numero_cuotas THEN v_ultima_cuota ELSE v_monto_cuota END,
            0,
            CASE WHEN v_i = p_numero_cuotas THEN v_ultima_cuota ELSE v_monto_cuota END,
            'Cuota ' || v_i || ' de ' || p_numero_cuotas,
            p_id_usuario,
            p_id_usuario
        );
    END LOOP;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            fc.id,
            UPPER(p_tipo) AS tipo,
            fc.id_tercero,
            fc.tercero_nombre,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            fc.descripcion,
            fc.fecha_emision,
            fc.monto_pendiente,
            fc.numero_cuotas_total,
            fc.id_banco,
            fc.tasa_interes,
            (
                SELECT COALESCE(json_agg(
                    json_build_object(
                        'id', h.id,
                        'numeroCuota', h.numero_cuota,
                        'fechaVencimiento', h.fecha_vencimiento,
                        'monto', h.monto_pendiente
                    ) ORDER BY h.numero_cuota
                ), '[]'::json)
                FROM fin_cuenta h
                WHERE h.id_cuenta_padre = fc.id AND h.estado = 1
            ) AS cuotas
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.id = v_id_padre
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$$;
