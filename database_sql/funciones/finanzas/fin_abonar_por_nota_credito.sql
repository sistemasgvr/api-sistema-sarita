-- Aplica la NC como abono a la CxC del comprobante origen (sin caja).
CREATE OR REPLACE FUNCTION fin_abonar_por_nota_credito(
    p_id_comprobante_origen INTEGER,
    p_id_nota_credito INTEGER,
    p_monto NUMERIC,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_restante NUMERIC(12,2);
    v_aplicar NUMERIC(12,2);
    v_hijo RECORD;
    v_serie VARCHAR;
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_restante := fin_redondear_monto(p_monto);
    IF v_restante IS NULL OR v_restante <= 0 OR p_id_comprobante_origen IS NULL THEN
        RETURN;
    END IF;

    SELECT serie, numero INTO v_serie, v_numero
    FROM ven_comprobante
    WHERE id = p_id_nota_credito;

    FOR v_hijo IN
        SELECT h.id, fin_redondear_monto(COALESCE(h.monto_saldo, 0)) AS saldo
        FROM fin_cuenta h
        WHERE h.estado = 1
          AND fin_redondear_monto(COALESCE(h.monto_saldo, 0)) > 0
          AND (
              (
                  h.id_comprobante_venta = p_id_comprobante_origen
                  AND h.id_cuenta_padre IS NULL
                  AND h.numero_cuotas_total IS NULL
              )
              OR h.id_cuenta_padre IN (
                  SELECT fc.id
                  FROM fin_cuenta fc
                  WHERE fc.id_comprobante_venta = p_id_comprobante_origen
                    AND fc.estado = 1
                    AND fc.id_cuenta_padre IS NULL
              )
          )
        ORDER BY COALESCE(h.numero_cuota, 0), h.fecha_vencimiento, h.id
    LOOP
        EXIT WHEN v_restante <= 0;
        IF v_hijo.saldo <= 0 THEN
            CONTINUE;
        END IF;

        v_aplicar := LEAST(v_restante, v_hijo.saldo);

        INSERT INTO fin_pago (
            id_cuenta, fecha_pago, monto, referencia, observacion, id_sucursal, id_usuario_creacion
        ) VALUES (
            v_hijo.id,
            CURRENT_DATE,
            v_aplicar,
            format('NC %s-%s', COALESCE(v_serie, ''), COALESCE(v_numero, '')),
            format('Abono automático por nota de crédito #%s', p_id_nota_credito),
            fin_sucursal_de_cuenta(v_hijo.id),
            p_id_usuario
        );

        UPDATE fin_cuenta
        SET monto_abonado = fin_redondear_monto(COALESCE(monto_abonado, 0) + v_aplicar),
            monto_saldo = fin_redondear_monto(GREATEST(monto_saldo - v_aplicar, 0)),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_hijo.id;

        IF (SELECT id_cuenta_padre FROM fin_cuenta WHERE id = v_hijo.id) IS NOT NULL THEN
            PERFORM fin_refrescar_cabecera_plan(
                (SELECT id_cuenta_padre FROM fin_cuenta WHERE id = v_hijo.id)
            );
        END IF;

        v_restante := fin_redondear_monto(v_restante - v_aplicar);
    END LOOP;
END;
$function$;
