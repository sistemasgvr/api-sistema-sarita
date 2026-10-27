-- Garantías: edición de cualquier garantía (manual, préstamo, alquiler o POS). Reemplaza ven_actualizar_garantia_manual por ven_actualizar_garantia (medio, cuenta, nº de operación, monto, fecha, cliente; actualiza el cobro y devuelve avisos de caja cerrada o documento ligado) y amplía ven_obtener_garantia / ven_listar_garantias (medio, cuenta y nº de operación por movimiento, monto_transferido, puede_editar = activa).
-- Respaldar la base antes de aplicarlo; publicar junto con la API que llama a ven_actualizar_garantia y el admin con el nuevo detalle de garantía (la API anterior deja de poder editar).
-- PENDIENTE DE PUBLICAR: no ejecutar sin revisión. Idempotente (DROP FUNCTION IF EXISTS / CREATE OR REPLACE).
BEGIN;

DROP FUNCTION IF EXISTS public.ven_actualizar_garantia_manual (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_id_medio_pago integer,
  p_importe numeric,
  p_observacion character varying,
  p_id_usuario_auditoria integer,
  p_id_cuenta_bancaria integer
);

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

DROP FUNCTION IF EXISTS public.ven_obtener_garantia (p_id integer);

CREATE OR REPLACE FUNCTION public.ven_obtener_garantia (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            g.id_prestamo_detalle,
            g.id_garantia_origen,
            pr.numero_prestamo,
            pr.titulo AS titulo_prestamo,
            g.id_alquiler,
            al.numero_alquiler,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.precio_garantia AS precio_garantia_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_transferido,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.id_medio_pago,
            mp.nombre AS medio_pago,
            g.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            g.fecha_reembolso,
            g.id_medio_reembolso,
            mr.nombre AS medio_reembolso,
            g.id_cuenta_bancaria_reembolso,
            COALESCE(cbr.alias, cbr.titular, cbr.numero_cuenta) AS cuenta_bancaria_reembolso,
            g.observacion_reembolso,
            g.id_usuario_reembolso,
            g.estado,
            g.fecha_creacion,
            g.fecha_modificacion,
            CASE
                WHEN g.id_prestamo IS NOT NULL THEN 'PRESTAMO'
                WHEN g.id_alquiler IS NOT NULL THEN 'ALQUILER'
                WHEN EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                ) THEN 'POS'
                ELSE 'MANUAL'
            END AS origen,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS es_manual,
            (g.estado = 1) AS puede_editar,
            cob.numero_operacion,
            COALESCE(cob.fecha, g.fecha_registro) AS cobro_fecha,
            COALESCE(cob.id_medio_pago, g.id_medio_pago) AS cobro_id_medio_pago,
            mpc.nombre AS cobro_medio_pago,
            COALESCE(cob.id_cuenta_bancaria, g.id_cuenta_bancaria) AS cobro_id_cuenta_bancaria,
            COALESCE(cbc.alias, cbc.titular, cbc.numero_cuenta) AS cobro_cuenta_bancaria,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_eliminar,
            (
                SELECT CASE
                    WHEN vc.id IS NULL THEN NULL
                    ELSE CONCAT_WS('-', vc.serie, vc.numero)
                END
                FROM ven_garantia_movimiento gm
                LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS comprobante_cobro,
            g.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            g.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            (
                SELECT COALESCE(json_agg(row_to_json(m) ORDER BY m.fecha DESC, m.id DESC), '[]'::JSON)
                FROM (
                    SELECT
                        gm.id,
                        gm.id_garantia,
                        gm.id_tipo_movimiento,
                        tm.nombre AS nombre_tipo_movimiento,
                        gm.id_comprobante,
                        vc.serie AS serie_comprobante,
                        vc.numero AS numero_comprobante,
                        CASE
                            WHEN vc.id IS NULL THEN NULL
                            ELSE CONCAT_WS('-', vc.serie, vc.numero)
                        END AS comprobante,
                        gm.fecha,
                        gm.monto,
                        gm.observacion,
                        gm.id_medio_pago,
                        mpm.nombre AS medio_pago,
                        gm.id_cuenta_bancaria,
                        COALESCE(cbm.alias, cbm.titular, cbm.numero_cuenta) AS cuenta_bancaria,
                        gm.numero_operacion,
                        gm.id_sucursal,
                        gm.fecha_creacion
                    FROM ven_garantia_movimiento gm
                    LEFT JOIN gen_lista_opciones tm ON gm.id_tipo_movimiento = tm.id
                    LEFT JOIN ven_comprobante vc ON gm.id_comprobante = vc.id
                    LEFT JOIN gen_lista_opciones mpm ON gm.id_medio_pago = mpm.id
                    LEFT JOIN gen_cuenta_bancaria cbm ON cbm.id = gm.id_cuenta_bancaria
                    WHERE gm.id_garantia = g.id AND gm.estado = 1
                ) m
            ) AS movimientos
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON g.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN gen_lista_opciones mp ON g.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones mr ON g.id_medio_reembolso = mr.id
        LEFT JOIN gen_cuenta_bancaria cb  ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN gen_cuenta_bancaria cbr ON cbr.id = g.id_cuenta_bancaria_reembolso
        LEFT JOIN LATERAL (
            SELECT gm.fecha, gm.id_medio_pago, gm.id_cuenta_bancaria, gm.numero_operacion
            FROM ven_garantia_movimiento gm
            INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
            WHERE gm.id_garantia = g.id
              AND gm.estado = 1
              AND UPPER(tm.nombre) = 'COBRO'
            ORDER BY gm.fecha ASC, gm.id ASC
            LIMIT 1
        ) cob ON TRUE
        LEFT JOIN gen_lista_opciones mpc ON mpc.id = COALESCE(cob.id_medio_pago, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cbc ON cbc.id = COALESCE(cob.id_cuenta_bancaria, g.id_cuenta_bancaria)
        LEFT JOIN auth_usuarios uc ON g.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON g.id_usuario_modificacion = umod.id
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_listar_garantias (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_cliente integer,
  p_id_prestamo integer,
  p_id_estado integer,
  p_id_alquiler integer,
  p_estado_nombre character varying,
  p_desde date,
  p_hasta date
);

CREATE OR REPLACE FUNCTION public.ven_listar_garantias (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_prestamo integer DEFAULT NULL::integer,
  p_id_estado integer DEFAULT NULL::integer,
  p_id_alquiler integer DEFAULT NULL::integer,
  p_estado_nombre character varying DEFAULT NULL::character varying,
  p_desde date DEFAULT NULL::date,
  p_hasta date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM ven_garantia g
    LEFT JOIN cli_clientes c ON g.id_cliente = c.id
    LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
    LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
    LEFT JOIN pro_producto p ON g.id_producto = p.id
    LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
    WHERE g.estado = 1
      AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
      AND (p_id_alquiler IS NULL OR g.id_alquiler = p_id_alquiler)
      AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
      AND (p_estado_nombre IS NULL OR eg.nombre = UPPER(TRIM(p_estado_nombre)))
      AND (p_desde IS NULL OR g.fecha_registro >= p_desde)
      AND (p_hasta IS NULL OR g.fecha_registro <= p_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(
              COALESCE(
                  NULLIF(TRIM(c.razon_social), ''),
                  NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                  ''
              ),
              p_busqueda
          )
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.ubicacion, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(g.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.id_alquiler,
            al.numero_alquiler,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            g.cantidad_venta,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_transferido,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.id_medio_pago,
            mp.nombre AS medio_pago,
            g.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            g.fecha_reembolso,
            g.id_medio_reembolso,
            mr.nombre AS medio_reembolso,
            g.id_cuenta_bancaria_reembolso,
            COALESCE(cbr.alias, cbr.titular, cbr.numero_cuenta) AS cuenta_bancaria_reembolso,
            g.observacion_reembolso,
            g.estado,
            g.fecha_creacion,
            CASE
                WHEN g.id_prestamo IS NOT NULL THEN 'PRESTAMO'
                WHEN g.id_alquiler IS NOT NULL THEN 'ALQUILER'
                WHEN EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                ) THEN 'POS'
                ELSE 'MANUAL'
            END AS origen,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS es_manual,
            (g.estado = 1) AS puede_editar,
            cob.numero_operacion,
            COALESCE(cob.fecha, g.fecha_registro) AS cobro_fecha,
            COALESCE(cob.id_medio_pago, g.id_medio_pago) AS cobro_id_medio_pago,
            mpc.nombre AS cobro_medio_pago,
            COALESCE(cob.id_cuenta_bancaria, g.id_cuenta_bancaria) AS cobro_id_cuenta_bancaria,
            COALESCE(cbc.alias, cbc.titular, cbc.numero_cuenta) AS cobro_cuenta_bancaria,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_eliminar,
            (
                SELECT CASE
                    WHEN vc.id IS NULL THEN NULL
                    ELSE CONCAT_WS('-', vc.serie, vc.numero)
                END
                FROM ven_garantia_movimiento gm
                LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS comprobante_cobro,
            (
                SELECT gm.id_comprobante
                FROM ven_garantia_movimiento gm
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS id_comprobante_cobro
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN gen_lista_opciones mp ON g.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones mr ON g.id_medio_reembolso = mr.id
        LEFT JOIN gen_cuenta_bancaria cb  ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN gen_cuenta_bancaria cbr ON cbr.id = g.id_cuenta_bancaria_reembolso
        LEFT JOIN LATERAL (
            SELECT gm.fecha, gm.id_medio_pago, gm.id_cuenta_bancaria, gm.numero_operacion
            FROM ven_garantia_movimiento gm
            INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
            WHERE gm.id_garantia = g.id
              AND gm.estado = 1
              AND UPPER(tm.nombre) = 'COBRO'
            ORDER BY gm.fecha ASC, gm.id ASC
            LIMIT 1
        ) cob ON TRUE
        LEFT JOIN gen_lista_opciones mpc ON mpc.id = COALESCE(cob.id_medio_pago, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cbc ON cbc.id = COALESCE(cob.id_cuenta_bancaria, g.id_cuenta_bancaria)
        WHERE g.estado = 1
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
          AND (p_id_alquiler IS NULL OR g.id_alquiler = p_id_alquiler)
          AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
          AND (p_estado_nombre IS NULL OR eg.nombre = UPPER(TRIM(p_estado_nombre)))
          AND (p_desde IS NULL OR g.fecha_registro >= p_desde)
          AND (p_hasta IS NULL OR g.fecha_registro <= p_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(
                  COALESCE(
                      NULLIF(TRIM(c.razon_social), ''),
                      NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                      ''
                  ),
                  p_busqueda
              )
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(al.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.ubicacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(g.observacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(mp.nombre, ''), p_busqueda)
          )
        ORDER BY g.fecha_registro DESC, g.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

COMMIT;
