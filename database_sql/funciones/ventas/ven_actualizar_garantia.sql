-- Actualiza una garantía de cualquier origen y su cobro, devolviendo avisos de caja cerrada o documento ligado
DROP FUNCTION IF EXISTS public.ven_actualizar_garantia (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_monto numeric,
  p_observacion character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.ven_actualizar_garantia (
  p_id integer,
  p_fecha date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_monto numeric DEFAULT NULL::numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_garantia RECORD;
    v_medio_cobro INTEGER;
    v_cuenta_cobro INTEGER;
    v_id_tipo_cobro INTEGER;
    v_cant_cobros INTEGER;
    v_medio_actual INTEGER;
    v_cuenta_actual INTEGER;
    v_numero_actual VARCHAR(80);
    v_medio INTEGER;
    v_cuenta INTEGER;
    v_numero VARCHAR(80);
    v_sin_cuenta BOOLEAN;
    v_fecha DATE;
    v_monto NUMERIC(12,4);
    v_devuelto NUMERIC(12,4);
    v_transferido NUMERIC(12,4);
    v_saldo NUMERIC(12,4);
    v_nombre_estado VARCHAR;
    v_id_estado INTEGER;
    v_fecha_reembolso DATE;
    v_cliente_doc INTEGER;
    v_doc TEXT;
    v_afecta_caja BOOLEAN;
    v_error TEXT;
    v_avisos TEXT[] := ARRAY[]::TEXT[];
    v_aviso TEXT;
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id IS NULL THEN
        RETURN json_build_object('error', 'El id de garantía es obligatorio', 'registro', NULL);
    END IF;

    SELECT * INTO v_garantia
    FROM ven_garantia
    WHERE id = p_id AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Garantía no encontrada', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_medio_pago AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El método de pago indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_cobro
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_cobro IS NULL THEN
        RETURN json_build_object('error', 'Falta opción TipoMovimientoGarantia.COBRO en catálogo', 'registro', NULL);
    END IF;

    SELECT COUNT(*) INTO v_cant_cobros
    FROM ven_garantia_movimiento gm
    WHERE gm.id_garantia = p_id AND gm.estado = 1 AND gm.id_tipo_movimiento = v_id_tipo_cobro;

    SELECT gm.id_medio_pago, gm.id_cuenta_bancaria, gm.numero_operacion
    INTO v_medio_cobro, v_cuenta_cobro, v_numero_actual
    FROM ven_garantia_movimiento gm
    WHERE gm.id_garantia = p_id AND gm.estado = 1 AND gm.id_tipo_movimiento = v_id_tipo_cobro
    ORDER BY gm.fecha ASC, gm.id ASC
    LIMIT 1;

    v_medio_actual := COALESCE(v_medio_cobro, v_garantia.id_medio_pago);
    v_cuenta_actual := COALESCE(v_cuenta_cobro, v_garantia.id_cuenta_bancaria);

    v_medio := COALESCE(p_id_medio_pago, v_medio_actual);
    v_sin_cuenta := v_medio IS NULL
        OR fin_medio_pago_flag(v_medio, 'ES_EFECTIVO')
        OR fin_medio_pago_flag(v_medio, 'ES_CREDITO');
    v_cuenta := CASE
        WHEN v_sin_cuenta THEN NULL
        WHEN p_id_cuenta_bancaria IS NOT NULL THEN p_id_cuenta_bancaria
        WHEN v_medio IS DISTINCT FROM v_medio_actual THEN NULL
        ELSE v_cuenta_actual
    END;

    v_error := fin_validar_cuenta_medio_pago(v_medio, v_cuenta);
    IF v_error IS NOT NULL THEN
        RETURN json_build_object('error', v_error, 'registro', NULL);
    END IF;

    v_numero := CASE
        WHEN v_sin_cuenta THEN NULL
        WHEN p_numero_operacion IS NULL THEN v_numero_actual
        ELSE NULLIF(TRIM(p_numero_operacion), '')
    END;

    v_fecha := COALESCE(p_fecha, v_garantia.fecha_registro);
    v_devuelto := COALESCE(v_garantia.monto_devuelto, 0);
    v_transferido := COALESCE(v_garantia.monto_transferido, 0);
    v_monto := COALESCE(ROUND(p_monto::NUMERIC, 4), v_garantia.monto_cobrado);

    IF v_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_monto < v_devuelto + v_transferido THEN
        RETURN json_build_object(
            'error',
            'El monto (' || to_char(v_monto, 'FM999999990.00') || ') no puede ser menor a lo ya devuelto y transferido ('
                || to_char(v_devuelto + v_transferido, 'FM999999990.00') || ')',
            'registro',
            NULL
        );
    END IF;

    IF v_monto IS DISTINCT FROM v_garantia.monto_cobrado AND v_cant_cobros <> 1 THEN
        RETURN json_build_object(
            'error',
            CASE
                WHEN v_cant_cobros = 0 THEN 'No se puede cambiar el monto: la garantía no tiene un cobro registrado (viene de una transferencia)'
                ELSE 'No se puede cambiar el monto: la garantía tiene ' || v_cant_cobros || ' cobros registrados'
            END,
            'registro',
            NULL
        );
    END IF;

    IF v_cant_cobros > 1 AND (
        v_medio IS DISTINCT FROM v_medio_actual
        OR v_cuenta IS DISTINCT FROM v_cuenta_actual
        OR v_numero IS DISTINCT FROM v_numero_actual
        OR EXISTS (
            SELECT 1
            FROM ven_garantia_movimiento gm
            WHERE gm.id_garantia = p_id
              AND gm.estado = 1
              AND gm.id_tipo_movimiento = v_id_tipo_cobro
              AND gm.fecha IS DISTINCT FROM COALESCE(p_fecha, gm.fecha)
        )
    ) THEN
        RETURN json_build_object(
            'error',
            'La garantía tiene ' || v_cant_cobros || ' cobros registrados: solo se puede cambiar el cliente y la observación',
            'registro',
            NULL
        );
    END IF;

    v_saldo := ROUND(v_monto - v_devuelto - v_transferido, 4);

    v_nombre_estado := CASE
        WHEN v_saldo = 0 AND v_transferido > 0 THEN 'TRANSFERIDA'
        WHEN v_saldo = 0 THEN 'DEVUELTA'
        WHEN v_devuelto > 0 OR v_transferido > 0 THEN 'PARCIAL'
        ELSE 'ACTIVA'
    END;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = v_nombre_estado AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object(
            'error',
            'Falta opción EstadoGarantia.' || v_nombre_estado || ' en catálogo',
            'registro',
            NULL
        );
    END IF;

    v_fecha_reembolso := CASE
        WHEN v_nombre_estado <> 'DEVUELTA' THEN NULL
        ELSE COALESCE(
            v_garantia.fecha_reembolso,
            (
                SELECT MAX(gm.fecha)
                FROM ven_garantia_movimiento gm
                INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
                WHERE gm.id_garantia = p_id AND gm.estado = 1 AND UPPER(tm.nombre) = 'DEVOLUCION'
            )
        )
    END;

    IF p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM v_garantia.id_cliente THEN
        IF v_garantia.id_prestamo IS NOT NULL THEN
            SELECT pr.id_cliente, 'el préstamo ' || COALESCE(pr.numero_prestamo, pr.id::TEXT)
            INTO v_cliente_doc, v_doc
            FROM bal_prestamo pr
            WHERE pr.id = v_garantia.id_prestamo;
        ELSIF v_garantia.id_alquiler IS NOT NULL THEN
            SELECT al.id_cliente, 'el alquiler ' || COALESCE(al.numero_alquiler, al.id::TEXT)
            INTO v_cliente_doc, v_doc
            FROM bal_alquiler al
            WHERE al.id = v_garantia.id_alquiler;
        ELSE
            SELECT vc.id_cliente, 'el comprobante ' || CONCAT_WS('-', vc.serie, vc.numero)
            INTO v_cliente_doc, v_doc
            FROM ven_garantia_movimiento gm
            INNER JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
            WHERE gm.id_garantia = p_id AND gm.estado = 1 AND gm.id_comprobante IS NOT NULL
            ORDER BY gm.fecha ASC, gm.id ASC
            LIMIT 1;
        END IF;

        IF v_doc IS NOT NULL AND v_cliente_doc IS DISTINCT FROM p_id_cliente THEN
            v_avisos := v_avisos || ('El cliente ya no coincide con el de ' || v_doc);
        END IF;
    END IF;

    v_afecta_caja :=
        v_fecha IS DISTINCT FROM v_garantia.fecha_registro
        OR v_monto IS DISTINCT FROM v_garantia.monto_cobrado
        OR v_medio IS DISTINCT FROM v_medio_actual
        OR v_cuenta IS DISTINCT FROM v_cuenta_actual
        OR EXISTS (
            SELECT 1
            FROM ven_garantia_movimiento gm
            WHERE gm.id_garantia = p_id
              AND gm.estado = 1
              AND gm.id_tipo_movimiento = v_id_tipo_cobro
              AND (
                  gm.fecha IS DISTINCT FROM COALESCE(p_fecha, gm.fecha)
                  OR COALESCE(gm.id_medio_pago, v_garantia.id_medio_pago) IS DISTINCT FROM v_medio
                  OR gm.id_cuenta_bancaria IS DISTINCT FROM v_cuenta
              )
        );

    IF v_afecta_caja THEN
        FOR v_aviso IN
            SELECT DISTINCT format(
                'La caja del %s está cerrada: sus totales no cambian hasta reabrirla y cerrarla',
                to_char(f.fecha, 'DD/MM/YYYY')
            )
            FROM ven_garantia_movimiento gm
            LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
            CROSS JOIN LATERAL (VALUES (gm.fecha), (COALESCE(p_fecha, gm.fecha))) AS f(fecha)
            INNER JOIN fin_caja_sesion s
                ON s.estado = 1
               AND s.fecha = f.fecha
               AND COALESCE(s.id_sucursal, 0) = COALESCE(gm.id_sucursal, vc.id_sucursal, 0)
            INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
            WHERE gm.id_garantia = p_id
              AND gm.estado = 1
              AND gm.id_tipo_movimiento = v_id_tipo_cobro
              AND UPPER(est.nombre) = 'CERRADA'
              AND s.id = (
                  SELECT s2.id
                  FROM fin_caja_sesion s2
                  WHERE s2.estado = 1
                    AND s2.fecha = f.fecha
                    AND COALESCE(s2.id_sucursal, 0) = COALESCE(gm.id_sucursal, vc.id_sucursal, 0)
                  ORDER BY s2.id DESC
                  LIMIT 1
              )
        LOOP
            v_avisos := v_avisos || v_aviso;
        END LOOP;

        FOR v_aviso IN
            SELECT DISTINCT format(
                'No hay caja para el %s: el cobro se contará cuando se abra',
                to_char(p_fecha, 'DD/MM/YYYY')
            )
            FROM ven_garantia_movimiento gm
            LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
            WHERE p_fecha IS NOT NULL
              AND gm.id_garantia = p_id
              AND gm.estado = 1
              AND gm.id_tipo_movimiento = v_id_tipo_cobro
              AND gm.fecha IS DISTINCT FROM p_fecha
              AND NOT EXISTS (
                  SELECT 1
                  FROM fin_caja_sesion s
                  WHERE s.estado = 1
                    AND s.fecha = p_fecha
                    AND COALESCE(s.id_sucursal, 0) = COALESCE(gm.id_sucursal, vc.id_sucursal, 0)
              )
        LOOP
            v_avisos := v_avisos || v_aviso;
        END LOOP;
    END IF;

    UPDATE ven_garantia
    SET
        fecha_registro = v_fecha,
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_medio_pago = v_medio,
        id_cuenta_bancaria = v_cuenta,
        monto_cobrado = v_monto,
        monto_saldo = v_saldo,
        id_estado = v_id_estado,
        fecha_reembolso = v_fecha_reembolso,
        observacion = CASE
            WHEN p_observacion IS NULL THEN observacion
            WHEN TRIM(p_observacion) = '' THEN NULL
            ELSE TRIM(p_observacion)
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    UPDATE ven_garantia_movimiento gm
    SET
        monto = v_monto,
        fecha = COALESCE(p_fecha, gm.fecha),
        id_medio_pago = v_medio,
        id_cuenta_bancaria = v_cuenta,
        numero_operacion = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE v_cant_cobros = 1
      AND gm.id_garantia = p_id
      AND gm.estado = 1
      AND gm.id_tipo_movimiento = v_id_tipo_cobro;

    v_resultado := ven_obtener_garantia(p_id);

    RETURN json_build_object(
        'registro',
        v_resultado -> 'registro',
        'avisos',
        to_json(v_avisos)
    );
END;
$function$;
