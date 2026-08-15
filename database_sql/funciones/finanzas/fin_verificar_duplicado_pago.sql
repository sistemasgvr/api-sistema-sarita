-- Detecta si un pago que se va a registrar podría estar duplicado.
-- Reglas (OR):
--   * alta / factura: mismo tercero + mismo nº de comprobante (cuenta o doc vinculado)
--   * alta / exacto: mismo tercero + mismo monto + misma fecha
--   * media / reciente: mismo tercero + mismo monto en ventana de días (±7)

DROP FUNCTION IF EXISTS fin_verificar_duplicado_pago(INT, DATE, NUMERIC, INT, VARCHAR);

CREATE OR REPLACE FUNCTION fin_verificar_duplicado_pago(
    p_id_cuenta          INT,
    p_fecha_pago         DATE,
    p_monto              NUMERIC,
    p_dias_ventana       INT     DEFAULT 7,
    p_numero_comprobante VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_cuenta           fin_cuenta%ROWTYPE;
    v_id_tercero       INT;
    v_tercero_nombre   VARCHAR;
    v_comp             VARCHAR;
    v_pago_factura     RECORD;
    v_pago_exacto      RECORD;
    v_pago_probable    RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = p_id_cuenta AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('duplicado', false);
    END IF;

    v_id_tercero     := v_cuenta.id_tercero;
    v_tercero_nombre := v_cuenta.tercero_nombre;
    v_comp := NULLIF(TRIM(COALESCE(
        NULLIF(TRIM(p_numero_comprobante), ''),
        (
            SELECT NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-')
            FROM ven_comprobante vc
            WHERE vc.id = v_cuenta.id_comprobante_venta
        ),
        (
            SELECT NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-')
            FROM com_comprobante_compra cc
            WHERE cc.id = v_cuenta.id_comprobante_compra
        ),
        v_cuenta.numero_comprobante
    )), '');

    -- 1) MISMO COMPROBANTE al mismo tercero (independiente del monto) → alta
    IF v_comp IS NOT NULL THEN
        SELECT
            p.id,
            p.fecha_pago,
            p.monto,
            COALESCE(
                NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-'),
                NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-'),
                c.numero_comprobante
            ) AS numero_comprobante,
            c.id AS id_cuenta
          INTO v_pago_factura
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        LEFT JOIN ven_comprobante vc ON vc.id = c.id_comprobante_venta
        LEFT JOIN com_comprobante_compra cc ON cc.id = c.id_comprobante_compra
        WHERE p.estado = 1
          AND c.estado = 1
          AND (
            (v_id_tercero IS NOT NULL AND c.id_tercero = v_id_tercero)
            OR (v_id_tercero IS NULL AND v_tercero_nombre IS NOT NULL AND c.tercero_nombre = v_tercero_nombre)
          )
          AND UPPER(REPLACE(COALESCE(
                NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-'),
                NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-'),
                c.numero_comprobante,
                ''
              ), ' ', '')) = UPPER(REPLACE(v_comp, ' ', ''))
        ORDER BY p.id DESC
        LIMIT 1;

        IF v_pago_factura.id IS NOT NULL THEN
            RETURN json_build_object(
                'duplicado', true,
                'severidad', 'alta',
                'mensaje', format(
                    'Ya hay un pago registrado para el mismo comprobante (%s) de este tercero el %s por %s.',
                    v_comp,
                    to_char(v_pago_factura.fecha_pago, 'DD/MM/YYYY'),
                    to_char(v_pago_factura.monto, 'FM999,999,990.00')
                ),
                'pagoExistente', json_build_object(
                    'id', v_pago_factura.id,
                    'idCuenta', v_pago_factura.id_cuenta,
                    'fechaPago', v_pago_factura.fecha_pago,
                    'monto', v_pago_factura.monto,
                    'numeroComprobante', v_pago_factura.numero_comprobante
                )
            );
        END IF;
    END IF;

    -- 2) DUPLICADO EXACTO: mismo tercero + monto + fecha
    SELECT p.id, p.fecha_pago, p.monto, c.numero_comprobante, c.id AS id_cuenta
      INTO v_pago_exacto
    FROM fin_pago p
    JOIN fin_cuenta c ON c.id = p.id_cuenta
    WHERE p.estado = 1
      AND p.fecha_pago = p_fecha_pago
      AND ABS(p.monto - p_monto) < 0.0001
      AND (
        (v_id_tercero IS NOT NULL AND c.id_tercero = v_id_tercero)
        OR (v_id_tercero IS NULL AND v_tercero_nombre IS NOT NULL AND c.tercero_nombre = v_tercero_nombre)
      )
    ORDER BY p.id DESC
    LIMIT 1;

    IF v_pago_exacto.id IS NOT NULL THEN
        RETURN json_build_object(
            'duplicado', true,
            'severidad', 'alta',
            'mensaje', format(
                'Ya existe un pago del mismo monto (%s) en la misma fecha (%s) para este tercero.',
                to_char(p_monto, 'FM999,999,990.00'),
                to_char(p_fecha_pago, 'DD/MM/YYYY')
            ),
            'pagoExistente', json_build_object(
                'id', v_pago_exacto.id,
                'idCuenta', v_pago_exacto.id_cuenta,
                'fechaPago', v_pago_exacto.fecha_pago,
                'monto', v_pago_exacto.monto,
                'numeroComprobante', v_pago_exacto.numero_comprobante
            )
        );
    END IF;

    -- 3) DUPLICADO PROBABLE: mismo tercero + mismo monto en la ventana de días
    SELECT p.id, p.fecha_pago, p.monto, c.id AS id_cuenta
      INTO v_pago_probable
    FROM fin_pago p
    JOIN fin_cuenta c ON c.id = p.id_cuenta
    WHERE p.estado = 1
      AND ABS(p.monto - p_monto) < 0.0001
      AND p.fecha_pago BETWEEN (p_fecha_pago - COALESCE(p_dias_ventana, 7))
                          AND (p_fecha_pago + COALESCE(p_dias_ventana, 7))
      AND (
        (v_id_tercero IS NOT NULL AND c.id_tercero = v_id_tercero)
        OR (v_id_tercero IS NULL AND v_tercero_nombre IS NOT NULL AND c.tercero_nombre = v_tercero_nombre)
      )
    ORDER BY p.fecha_pago DESC, p.id DESC
    LIMIT 1;

    IF v_pago_probable.id IS NOT NULL THEN
        RETURN json_build_object(
            'duplicado', true,
            'severidad', 'media',
            'mensaje', format(
                'A este tercero se le registró un pago por %s el %s. ¿Confirmas que no es el mismo pago?',
                to_char(p_monto, 'FM999,999,990.00'),
                to_char(v_pago_probable.fecha_pago, 'DD/MM/YYYY')
            ),
            'pagoExistente', json_build_object(
                'id', v_pago_probable.id,
                'idCuenta', v_pago_probable.id_cuenta,
                'fechaPago', v_pago_probable.fecha_pago,
                'monto', v_pago_probable.monto
            )
        );
    END IF;

    RETURN json_build_object('duplicado', false);
END;
$$;
