-- Regularización tras las NC FC01-00000001..05 rechazadas (código 3246) sobre F002-00000197 (id 464).
-- Diagnóstico en producción (17/11/2026):
--   * La primera NC (id 465, 12:02) cerró la custodia de la factura: el préstamo #294 quedó devuelto y la orden de
--     salida OS-01-2026-000264 ANULADA. El cilindro YA20Y504028 (#426) estaba PENDIENTE_ENVIO, así que la devolución
--     del préstamo no registró movimiento y doc_anular_salida lo dejó DISPONIBLE con un UPDATE directo, sin movimiento y
--     con el cliente 316 aún como ubicación. Por eso su historial termina en "Salida préstamo".
--   * No hubo abonos AJUSTE_NC (la factura no tenía saldo): no hay nada que anular en finanzas.
-- Corrección: registrar la ENTRADA_DEVOLUCION que faltó, en el momento real (12:02:16), ligada a la OS anulada, igual
-- que lo hace ahora doc_anular_salida. Cuando la nueva NC sea ACEPTADA no se duplica: el último movimiento ya es entrada.
-- Ejecutar DESPUÉS de migraciones/20261117_nc_custodia_al_aceptar.sql, en la misma transacción.
DO $correccion$
DECLARE
    v_ult RECORD;
    v_mov JSON;
BEGIN
    SET LOCAL TIME ZONE 'America/Lima';

    PERFORM 1 FROM bal_balon b
    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = 426 AND b.codigo_balon = 'YA20Y504028' AND b.estado = 1
      AND eb.nombre = 'DISPONIBLE' AND b.id_almacen = 2
    FOR UPDATE OF b;
    IF NOT FOUND THEN RAISE EXCEPTION 'El cilindro #426 ya no está DISPONIBLE en el almacén 2: revisar antes de corregir'; END IF;

    SELECT m.id, tm.nombre INTO v_ult
    FROM inv_movimiento m JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
    WHERE m.estado = 1 AND m.naturaleza = 'BALON' AND m.id_balon = 426
    ORDER BY m.fecha DESC, m.id DESC LIMIT 1;
    IF v_ult.id IS DISTINCT FROM 1740 OR v_ult.nombre <> 'SALIDA_PRESTAMO' THEN
        RAISE EXCEPTION 'El último movimiento del cilindro ya no es la Salida préstamo #1740 (es #% %)', v_ult.id, v_ult.nombre;
    END IF;

    PERFORM 1 FROM doc_salida d JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = 264 AND d.id_venta = 464 AND ec.nombre = 'ANULADA';
    IF NOT FOUND THEN RAISE EXCEPTION 'La orden OS-01-2026-000264 no está ANULADA'; END IF;

    v_mov := inv_registrar_movimiento(
        p_naturaleza                   => 'BALON',
        p_codigo_tipo_movimiento       => 'ENTRADA_DEVOLUCION',
        p_fecha                        => TIMESTAMP '2026-11-17 12:02:16.676',
        p_id_balon                     => 426,
        p_cantidad                     => 1,
        p_id_almacen_destino           => 2,
        p_id_cliente                   => 316,
        p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
        p_id_documento_origen          => 264,
        p_glosa                        => 'Retorno a almacén por anulación de orden OS-01-2026-000264: nota de crédito sobre F002-00000197',
        p_id_usuario_auditoria         => 3,
        p_forzar                       => TRUE
    );
    IF v_mov->>'error' IS NOT NULL THEN RAISE EXCEPTION '%', v_mov->>'error'; END IF;
    RAISE NOTICE 'Movimiento registrado: %', v_mov->'registro'->>'id';
END;
$correccion$;
