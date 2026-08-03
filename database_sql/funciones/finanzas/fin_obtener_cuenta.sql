-- Detalle de una cuenta financiera con su historial de pagos activos.
-- Si es cabecera de un plan de cuotas (numero_cuotas_total IS NOT NULL),
-- incluye también el arreglo de cuotas hijas con su estado calculado.

DROP FUNCTION IF EXISTS fin_obtener_cuenta(INT, VARCHAR);

CREATE OR REPLACE FUNCTION fin_obtener_cuenta(
    p_id   INT,
    p_tipo VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_registro JSON;
    v_id_tipo  INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_tipo IS NOT NULL THEN
        SELECT glo.id INTO v_id_tipo
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera'
          AND glo.nombre = UPPER(p_tipo)
        LIMIT 1;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            fc.id,
            fc.id_tipo_cuenta,
            tcu.nombre AS tipo,
            fc.id_tercero,
            fc.tercero_nombre,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            fc.id_comprobante_venta,
            fc.id_comprobante_compra,
            fc.id_cuenta_padre,
            fc.numero_cuota,
            fc.numero_cuotas_total,
            fc.descripcion,
            fc.id_banco,
            ban.nombre AS banco,
            fc.tasa_interes,
            fc.numero_comprobante,
            COALESCE(
                NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-'),
                NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-'),
                fc.numero_comprobante
            ) AS comprobante,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            fc.monto_pendiente,
            COALESCE(fc.monto_abonado, 0) AS monto_abonado,
            COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)) AS saldo,
            CASE
                WHEN COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)) <= 0 THEN 'PAGADO'
                WHEN fc.fecha_vencimiento IS NOT NULL AND fc.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
                WHEN COALESCE(fc.monto_abonado, 0) > 0 THEN 'PARCIAL'
                ELSE 'PENDIENTE'
            END AS estado_calculado,
            fc.observacion,
            -- Cuotas hijas (solo cuando es cabecera de plan)
            (
                SELECT COALESCE(json_agg(
                    json_build_object(
                        'id', h.id,
                        'numeroCuota', h.numero_cuota,
                        'fechaVencimiento', h.fecha_vencimiento,
                        'montoPendiente', h.monto_pendiente,
                        'montoAbonado', COALESCE(h.monto_abonado, 0),
                        'saldo', COALESCE(h.monto_saldo, h.monto_pendiente - COALESCE(h.monto_abonado, 0)),
                        'estadoCalculado',
                        CASE
                            WHEN COALESCE(h.monto_saldo, h.monto_pendiente - COALESCE(h.monto_abonado, 0)) <= 0 THEN 'PAGADO'
                            WHEN h.fecha_vencimiento IS NOT NULL AND h.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
                            WHEN COALESCE(h.monto_abonado, 0) > 0 THEN 'PARCIAL'
                            ELSE 'PENDIENTE'
                        END
                    ) ORDER BY h.numero_cuota
                ), '[]'::json)
                FROM fin_cuenta h
                WHERE h.id_cuenta_padre = fc.id AND h.estado = 1
            ) AS cuotas,
            -- Pagos aplicados directamente a esta cuenta
            COALESCE((
                SELECT json_agg(
                    json_build_object(
                        'id', p.id,
                        'fechaPago', p.fecha_pago,
                        'monto', p.monto,
                        'idMedioPago', p.id_medio_pago,
                        'medioPago', mp.nombre,
                        'idCuentaBancaria', p.id_cuenta_bancaria,
                        'numeroOperacion', p.numero_operacion,
                        'referencia', p.referencia,
                        'observacion', p.observacion,
                        'fechaCreacion', p.fecha_creacion
                    )
                    ORDER BY p.fecha_pago DESC, p.id DESC
                )
                FROM fin_pago p
                LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
                WHERE p.id_cuenta = fc.id AND p.estado = 1
            ), '[]'::json) AS pagos
        FROM fin_cuenta fc
        JOIN gen_lista_opciones tcu ON tcu.id = fc.id_tipo_cuenta
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        LEFT JOIN gen_lista_opciones ban ON ban.id = fc.id_banco
        LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
        LEFT JOIN com_comprobante_compra cc ON cc.id = fc.id_comprobante_compra
        WHERE fc.id = p_id
          AND fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$$;
