-- Function: fin_abonar_por_nota_credito
-- P0: el abono automático lleva medio AJUSTE_NC (AFECTA_CAJA=false) para que
-- caja no haga COALESCE(null → efectivo) y cuente la NC como cobranza en efectivo.

DROP FUNCTION IF EXISTS fin_abonar_por_nota_credito(p_id_comprobante_origen integer, p_id_nota_credito integer, p_monto numeric, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_abonar_por_nota_credito(p_id_comprobante_origen integer, p_id_nota_credito integer, p_monto numeric, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_restante NUMERIC(12,2);
    v_aplicar NUMERIC(12,2);
    v_hijo RECORD;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_id_medio_nc INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_restante := fin_redondear_monto(p_monto);
    IF v_restante IS NULL OR v_restante <= 0 OR p_id_comprobante_origen IS NULL THEN
        RETURN;
    END IF;

    -- Medio interno no-caja: no exige cuenta bancaria y no entra al arqueo.
    SELECT o.id INTO v_id_medio_nc
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'AJUSTE_NC'
      AND o.estado = 1
    LIMIT 1;

    IF v_id_medio_nc IS NULL THEN
        RAISE EXCEPTION
            'Falta el medio de pago AJUSTE_NC en el catálogo MedioPago (con fin_medio_pago_config.afecta_caja=false). Se usa para abonos automáticos por nota de crédito.'
            USING ERRCODE = '22023';
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
        FOR UPDATE
    LOOP
        EXIT WHEN v_restante <= 0;
        IF v_hijo.saldo <= 0 THEN
            CONTINUE;
        END IF;

        v_aplicar := LEAST(v_restante, v_hijo.saldo);

        INSERT INTO fin_pago (
            id_cuenta, fecha_pago, monto, id_medio_pago,
            referencia, observacion, id_sucursal, id_usuario_creacion
        ) VALUES (
            v_hijo.id,
            CURRENT_DATE,
            v_aplicar,
            v_id_medio_nc,
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
