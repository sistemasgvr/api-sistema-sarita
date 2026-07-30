-- Clientes con deuda (cuentas por cobrar) con su detalle de comprobantes y productos.
-- Filtros opcionales: cliente y rango de fecha de emisión.

DROP FUNCTION IF EXISTS dash_clientes_con_deuda();

CREATE OR REPLACE FUNCTION dash_clientes_con_deuda(
    p_id_cliente  INT  DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_tipo_cobrar INT;
  v_result JSON;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT glo.id INTO v_id_tipo_cobrar
  FROM gen_lista_opciones glo
  JOIN gen_lista gl ON gl.id = glo.id_lista
  WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
  LIMIT 1;

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(cliente_deuda), '[]'::json)
  )
  INTO v_result
  FROM (
    SELECT
      c.id AS "idCliente",
      c.razon_social AS "razonSocial",
      c.nombres,
      c.numero_documento AS "numeroDocumento",
      SUM(fc.monto_saldo) AS "montoTotalDeuda",
      json_agg(
        json_build_object(
          'idCuenta', fc.id,
          'idComprobante', fc.id_comprobante_venta,
          'serie', vc.serie,
          'numero', vc.numero,
          'fechaEmision', fc.fecha_emision,
          'fechaVencimiento', fc.fecha_vencimiento,
          'montoSaldo', fc.monto_saldo,
          'productos', (
            SELECT COALESCE(json_agg(
              json_build_object(
                'idProducto', p.id,
                'nombre', p.nombre,
                'cantidad', vcd.cantidad,
                'importe', vcd.importe
              )
            ), '[]'::json)
            FROM ven_comprobante_detalle vcd
            JOIN pro_producto p ON p.id = vcd.id_producto
            WHERE vcd.id_comprobante = fc.id_comprobante_venta
              AND vcd.estado = 1
          )
        )
        ORDER BY fc.fecha_vencimiento
      ) AS comprobantes
    FROM fin_cuenta fc
    JOIN cli_clientes c ON c.id = fc.id_tercero
    LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
    WHERE fc.id_tipo_cuenta = v_id_tipo_cobrar
      AND fc.monto_saldo > 0
      AND fc.estado = 1
      AND (p_id_cliente IS NULL OR c.id = p_id_cliente)
      AND (p_fecha_desde IS NULL OR fc.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fc.fecha_emision <= p_fecha_hasta)
    GROUP BY c.id, c.razon_social, c.nombres, c.numero_documento
  ) cliente_deuda;

  RETURN v_result;
END;
$$;
