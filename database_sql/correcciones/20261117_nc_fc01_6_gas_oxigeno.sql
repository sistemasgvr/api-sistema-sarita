-- Reingreso de los 10 de OXIGENO INDUSTRIAL (producto 9) de la NC FC01-00000006 (id 474) sobre F002-00000197 (id 464).
-- El cilindro YA20Y504028 volvió lleno (la orden OS-01-2026-000264 nunca se despachó) y la NC no movió el gas.
-- Mismo movimiento que ahora hace ven_cerrar_custodia_comprobante, en la fecha en que SUNAT aceptó la NC.
DO $correccion$
DECLARE
    v_stock_antes NUMERIC;
    v_stock_despues NUMERIC;
    v_mov JSON;
BEGIN
    SET LOCAL TIME ZONE 'America/Lima';

    PERFORM 1 FROM ven_comprobante c
    JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat AND es.nombre = 'ACEPTADO'
    WHERE c.id = 474 AND c.estado = 1 AND c.id_comprobante_origen = 464;
    IF NOT FOUND THEN RAISE EXCEPTION 'La NC #474 no está ACEPTADA sobre la factura #464'; END IF;

    PERFORM 1 FROM ven_comprobante_detalle d
    WHERE d.id = 704 AND d.id_comprobante = 474 AND d.estado = 1
      AND d.id_producto = 9 AND d.cantidad = 10 AND d.id_balon = 426;
    IF NOT FOUND THEN RAISE EXCEPTION 'La línea #704 de la NC no coincide (oxígeno 10 con cilindro #426)'; END IF;

    IF EXISTS (
        SELECT 1 FROM inv_movimiento m
        JOIN gen_lista_opciones td ON td.id = m.id_tipo_documento_origen AND td.nombre = 'NOTA_CREDITO'
        WHERE m.estado = 1 AND m.id_documento_origen = 474 AND m.id_producto = 9
    ) THEN RAISE EXCEPTION 'Ya existe un movimiento de oxígeno para la NC #474'; END IF;

    SELECT stock INTO v_stock_antes FROM pro_stock WHERE id_almacen = 2 AND id_producto = 9 AND estado = 1;

    v_mov := inv_registrar_movimiento(
        p_naturaleza                   => 'PRODUCTO',
        p_codigo_tipo_movimiento       => 'INGRESO',
        p_fecha                        => TIMESTAMP '2026-11-17 16:58:53',
        p_id_producto                  => 9,
        p_cantidad                     => 10,
        p_id_almacen_origen            => 2,
        p_codigo_tipo_documento_origen => 'NOTA_CREDITO',
        p_id_documento_origen          => 474,
        p_id_documento_detalle         => 704,
        p_glosa                        => 'Retorno de gas en cilindro no entregado: nota de crédito FC01-00000006 (anula F002-00000197)',
        p_id_usuario_auditoria         => 3
    );
    IF v_mov->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_mov->>'error'; END IF;

    SELECT stock INTO v_stock_despues FROM pro_stock WHERE id_almacen = 2 AND id_producto = 9 AND estado = 1;
    IF v_stock_despues IS DISTINCT FROM v_stock_antes + 10 THEN
        RAISE EXCEPTION 'El stock no subió 10 (antes %, después %)', v_stock_antes, v_stock_despues;
    END IF;
    RAISE NOTICE 'Oxígeno almacén 2: % -> %', v_stock_antes, v_stock_despues;
END;
$correccion$;
