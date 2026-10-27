-- Publica en PROD los cambios de caja del 26/10: bitácora de apertura/cierre, conversión de VSD que no vuelve a sumar y libro diario.
-- Respaldar la base de PROD antes de aplicarlo; publicar junto con el admin que muestra la bitácora.
-- Extraído de sync-prod-desde-dev.sql (solo tabla fin_caja_sesion_evento, 6 funciones fin_* de caja y el llenado inicial).
BEGIN;

CREATE TABLE IF NOT EXISTS public.fin_caja_sesion_evento (
  id integer NOT NULL,
  id_sesion integer NOT NULL,
  tipo character varying(20) NOT NULL,
  monto numeric(12, 2),
  diferencia numeric(12, 2),
  observacion character varying(500),
  id_usuario integer,
  fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT fin_caja_sesion_evento_tipo_check CHECK (
    (
      (tipo)::text = ANY (
        (
          ARRAY[
            'ABRIR'::character varying,
            'CERRAR'::character varying,
            'REABRIR'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

CREATE SEQUENCE IF NOT EXISTS public.fin_caja_sesion_evento_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.fin_caja_sesion_evento_id_seq OWNED BY public.fin_caja_sesion_evento.id;

ALTER TABLE ONLY public.fin_caja_sesion_evento
ALTER COLUMN id
SET DEFAULT nextval('public.fin_caja_sesion_evento_id_seq'::regclass);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.fin_caja_sesion_evento'::regclass AND conname = 'fin_caja_sesion_evento_pkey') THEN
    ALTER TABLE ONLY public.fin_caja_sesion_evento
    ADD CONSTRAINT fin_caja_sesion_evento_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

CREATE INDEX IF NOT EXISTS idx_fin_caja_sesion_evento_sesion_fecha ON public.fin_caja_sesion_evento USING btree (id_sesion, fecha_hora);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.fin_caja_sesion_evento'::regclass AND conname = 'fin_caja_sesion_evento_id_sesion_fkey') THEN
    ALTER TABLE ONLY public.fin_caja_sesion_evento
    ADD CONSTRAINT fin_caja_sesion_evento_id_sesion_fkey FOREIGN KEY (id_sesion) REFERENCES public.fin_caja_sesion (id);
  END IF;
END
$sync$;

DROP FUNCTION IF EXISTS public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_abierta INT;
    v_existente RECORD;
    v_abierta RECORD;
    v_id INT;
    v_registro JSON;
    v_hora_txt TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_abierta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA'
    LIMIT 1;

    IF v_estado_abierta IS NULL THEN
        RETURN json_build_object('error', 'No existe estado de caja ABIERTA', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    IF COALESCE(p_monto_inicial, 0) < 0 THEN
        RETURN json_build_object('error', 'El monto inicial no puede ser negativo', 'registro', NULL);
    END IF;

    SELECT s.* INTO v_existente
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        v_hora_txt := to_char(v_existente.fecha_apertura AT TIME ZONE 'America/Lima', 'DD/MM/YYYY HH24:MI');
        RETURN json_build_object(
            'error', format(
                'Ya existe una sesión de caja para esa fecha (abierta el %s). No se puede repetir la misma fecha.',
                COALESCE(v_hora_txt, to_char(p_fecha, 'DD/MM/YYYY'))
            ),
            'registro', NULL
        );
    END IF;

    SELECT s.* INTO v_abierta
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.id_estado = v_estado_abierta
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        v_hora_txt := to_char(v_abierta.fecha_apertura AT TIME ZONE 'America/Lima', 'DD/MM/YYYY HH24:MI');
        RETURN json_build_object(
            'error', format(
                'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                COALESCE(v_hora_txt, '—')
            ),
            'registro', NULL
        );
    END IF;

    BEGIN
        INSERT INTO fin_caja_sesion (
            fecha, id_sucursal, id_estado, monto_inicial,
            observacion_apertura, fecha_apertura, id_usuario_apertura,
            id_usuario_creacion
        ) VALUES (
            p_fecha, p_id_sucursal, v_estado_abierta, COALESCE(p_monto_inicial, 0),
            NULLIF(TRIM(p_observacion), ''), NOW(), p_id_usuario,
            p_id_usuario
        )
        RETURNING id INTO v_id;
    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object(
                'error', 'Ya existe una sesión de caja para esa fecha / sucursal. No se puede repetir.',
                'registro', NULL
            );
    END;

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
    VALUES (v_id, 'ABRIR', ROUND(COALESCE(p_monto_inicial, 0), 2), NULLIF(TRIM(p_observacion), ''), p_id_usuario);

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id
    ) t;

    PERFORM fin_notificar_caja_admins(v_id, 'APERTURA', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer,
  p_observacion character varying,
  p_id_usuario integer,
  p_id_sesion integer
);

CREATE OR REPLACE FUNCTION public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer,
  p_id_sesion integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_abierta INT;
    v_estado_cerrada INT;
    v_existente RECORD;
    v_abierta RECORD;
    v_id INT;
    v_registro JSON;
    v_hora_txt TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_abierta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA'
    LIMIT 1;

    SELECT lo.id INTO v_estado_cerrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA'
    LIMIT 1;

    IF v_estado_abierta IS NULL THEN
        RETURN json_build_object('error', 'No existe estado de caja ABIERTA', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    IF COALESCE(p_monto_inicial, 0) < 0 THEN
        RETURN json_build_object('error', 'El monto inicial no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_sesion IS NOT NULL THEN
        SELECT s.* INTO v_existente
        FROM fin_caja_sesion s
        WHERE s.id = p_id_sesion
          AND s.estado = 1
        LIMIT 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
        END IF;

        IF v_existente.id_estado = v_estado_abierta THEN
            v_hora_txt := to_char(
                v_existente.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'La caja del %s ya está ABIERTA (desde %s).',
                    to_char(v_existente.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        SELECT s.* INTO v_abierta
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.id_estado = v_estado_abierta
          AND s.id <> v_existente.id
          AND COALESCE(s.id_sucursal, 0) = COALESCE(v_existente.id_sucursal, 0)
        LIMIT 1;

        IF FOUND THEN
            v_hora_txt := to_char(
                v_abierta.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'Ya hay otra caja ABIERTA del %s (apertura %s). Ciérrala antes de reabrir.',
                    to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        UPDATE fin_caja_sesion
        SET id_estado = v_estado_abierta,
            fecha_apertura = NOW(),
            id_usuario_apertura = p_id_usuario,
            observacion_apertura = NULLIF(TRIM(p_observacion), ''),
            monto_inicial = ROUND(COALESCE(p_monto_inicial, 0), 2),
            fecha_cierre = NULL,
            id_usuario_cierre = NULL,
            monto_efectivo_contado = NULL,
            monto_esperado = NULL,
            diferencia = NULL,
            observacion_cierre = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_existente.id
        RETURNING id INTO v_id;

        INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
        VALUES (v_id, 'REABRIR', ROUND(COALESCE(p_monto_inicial, 0), 2), NULLIF(TRIM(p_observacion), ''), p_id_usuario);

        SELECT row_to_json(t) INTO v_registro
        FROM (
            SELECT
                s.id,
                s.fecha,
                s.id_sucursal AS "idSucursal",
                suc.nombre AS "nombreSucursal",
                s.id_estado AS "idEstado",
                est.nombre AS "estadoCaja",
                s.monto_inicial AS "montoInicial",
                s.monto_efectivo_contado AS "montoEfectivoContado",
                s.monto_esperado AS "montoEsperado",
                s.diferencia,
                s.observacion_apertura AS "observacionApertura",
                s.observacion_cierre AS "observacionCierre",
                s.fecha_apertura AS "fechaApertura",
                s.fecha_cierre AS "fechaCierre",
                s.id_usuario_apertura AS "idUsuarioApertura",
                s.id_usuario_cierre AS "idUsuarioCierre"
            FROM fin_caja_sesion s
            LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
            LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
            WHERE s.id = v_id
        ) t;

        PERFORM fin_notificar_caja_admins(v_id, 'APERTURA', p_id_usuario);

        RETURN json_build_object('registro', v_registro);
    END IF;

    SELECT s.* INTO v_existente
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        IF v_existente.id_estado = v_estado_abierta THEN
            v_hora_txt := to_char(
                v_existente.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                    to_char(v_existente.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        RETURN json_build_object(
            'error', format(
                'La caja del %s ya fue cerrada. Para reabrirla usa la acción «Reabrir caja» (envía idSesion=%s).',
                to_char(v_existente.fecha, 'DD/MM/YYYY'),
                v_existente.id
            ),
            'registro', NULL
        );
    ELSE
        SELECT s.* INTO v_abierta
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.id_estado = v_estado_abierta
          AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
        LIMIT 1;

        IF FOUND THEN
            v_hora_txt := to_char(
                v_abierta.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                    to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        BEGIN
            INSERT INTO fin_caja_sesion (
                fecha, id_sucursal, id_estado, monto_inicial,
                observacion_apertura, fecha_apertura, id_usuario_apertura,
                id_usuario_creacion
            ) VALUES (
                p_fecha, p_id_sucursal, v_estado_abierta, ROUND(COALESCE(p_monto_inicial, 0), 2),
                NULLIF(TRIM(p_observacion), ''), NOW(), p_id_usuario,
                p_id_usuario
            )
            RETURNING id INTO v_id;
        EXCEPTION
            WHEN unique_violation THEN
                SELECT s.* INTO v_existente
                FROM fin_caja_sesion s
                WHERE s.estado = 1
                  AND s.fecha = p_fecha
                  AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
                LIMIT 1;

                IF FOUND AND v_existente.id_estado IS DISTINCT FROM v_estado_abierta THEN
                    RETURN json_build_object(
                        'error', format(
                            'La caja del %s ya fue cerrada. Para reabrirla usa la acción «Reabrir caja» (envía idSesion=%s).',
                            to_char(v_existente.fecha, 'DD/MM/YYYY'),
                            v_existente.id
                        ),
                        'registro', NULL
                    );
                END IF;

                RETURN json_build_object(
                    'error', 'Ya existe una sesión de caja para esa fecha y sucursal.',
                    'registro', NULL
                );
        END;

        INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
        VALUES (v_id, 'ABRIR', ROUND(COALESCE(p_monto_inicial, 0), 2), NULLIF(TRIM(p_observacion), ''), p_id_usuario);
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id
    ) t;

    PERFORM fin_notificar_caja_admins(v_id, 'APERTURA', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_caja_calcular_totales (p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION public.fin_caja_calcular_totales (
  p_fecha date,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_efectivo_id INT;
    v_ventas_contado NUMERIC(14,4) := 0;
    v_ventas_credito NUMERIC(14,4) := 0;
    v_ventas_caja NUMERIC(14,4) := 0;
    v_ventas_efectivo NUMERIC(14,4) := 0;
    v_ventas_otros NUMERIC(14,4) := 0;
    v_cobranzas NUMERIC(14,4) := 0;
    v_cobranzas_caja NUMERIC(14,4) := 0;
    v_cobranzas_efectivo NUMERIC(14,4) := 0;
    v_pagos_proveedor NUMERIC(14,4) := 0;
    v_pagos_proveedor_caja NUMERIC(14,4) := 0;
    v_gastos_caja NUMERIC(14,4) := 0;
    v_gastos_caja_medios NUMERIC(14,4) := 0;
    v_gastos_compra NUMERIC(14,4) := 0;
    v_depositos NUMERIC(14,4) := 0;
    v_garantias_cobro NUMERIC(14,4) := 0;
    v_garantias_cobro_caja NUMERIC(14,4) := 0;
    v_garantias_dev NUMERIC(14,4) := 0;
    v_garantias_dev_caja NUMERIC(14,4) := 0;
    v_por_medio JSON;
    v_efectivo_neto NUMERIC(14,4) := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    WITH mov AS (
        SELECT
            'VENTA'::TEXT AS tipo,
            COALESCE(pg.id_medio_pago, v_efectivo_id) AS id_medio_pago,
            pg.monto * CASE WHEN UPPER(COALESCE(tip.nombre, '')) = 'NOTA_CREDITO' THEN -1 ELSE 1 END AS monto
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        WHERE c.estado = 1
          AND c.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND NOT EXISTS (
              SELECT 1
              FROM ven_comprobante ori
              JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
              WHERE ori.id = c.id_comprobante_origen
                AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tip.descripcion, '') IN ('01', '03')
          )

        UNION ALL

        SELECT
            CASE WHEN UPPER(tc.nombre) = 'COBRAR' THEN 'COBRANZA' ELSE 'PAGO_PROVEEDOR' END,
            COALESCE(p.id_medio_pago, v_efectivo_id),
            p.monto
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        WHERE p.estado = 1
          AND p.fecha_pago = p_fecha
          AND UPPER(tc.nombre) IN ('COBRAR', 'PAGAR')
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        SELECT 'PAGO_PROVEEDOR', cc.id_medio_pago, cc.total_importe
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND cc.fecha = p_fecha
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )

        UNION ALL

        SELECT 'GASTO', COALESCE(g.id_medio_pago, v_efectivo_id), g.monto
        FROM fin_caja_gasto g
        LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion AND s.estado = 1
        WHERE g.estado = 1 AND g.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        SELECT 'DEPOSITO', v_efectivo_id, d.monto
        FROM fin_caja_deposito d
        LEFT JOIN fin_caja_sesion s ON s.id = d.id_sesion AND s.estado = 1
        WHERE d.estado = 1 AND d.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        SELECT 'GARANTIA_COBRO', COALESCE(gm.id_medio_pago, g.id_medio_pago, v_efectivo_id), gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'COBRO'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'GARANTIA_DEVOLUCION',
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago, v_efectivo_id),
            gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'DEVOLUCION'
          AND (
              p_id_sucursal IS NULL
              OR gm.id_sucursal = p_id_sucursal
          )
    ),
    m AS (
        SELECT
            mov.tipo,
            mov.id_medio_pago,
            mov.monto,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_CREDITO')  AS es_credito,
            fin_medio_pago_flag(mov.id_medio_pago, 'AFECTA_CAJA') AS afecta_caja,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_EFECTIVO') AS es_efectivo
        FROM mov
    ),
    por_medio AS (
        SELECT
            m.id_medio_pago,
            BOOL_OR(m.es_efectivo) AS es_efectivo,
            BOOL_OR(m.afecta_caja) AS afecta_caja,
            SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA') AS ventas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA') AS cobranzas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO') AS garantias_cobro,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO') AS gastos,
            SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR') AS pagos_proveedor,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION') AS garantias_devolucion,
            SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO') AS depositos
        FROM m
        WHERE NOT m.es_credito
        GROUP BY m.id_medio_pago
    )
    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito AND NOT m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION' AND m.afecta_caja), 0),
        COALESCE(SUM(CASE
            WHEN m.tipo IN ('VENTA', 'COBRANZA', 'GARANTIA_COBRO') THEN m.monto
            ELSE -m.monto END) FILTER (WHERE m.es_efectivo), 0),
        (
            SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.orden, r."medioPago"), '[]'::JSON)
            FROM (
                SELECT
                    pm.id_medio_pago AS "idMedioPago",
                    COALESCE(o.nombre, 'SIN MEDIO') AS "medioPago",
                    pm.es_efectivo AS "esEfectivo",
                    pm.afecta_caja AS "afectaCaja",
                    COALESCE(pm.ventas, 0) AS ventas,
                    COALESCE(pm.cobranzas, 0) AS cobranzas,
                    COALESCE(pm.garantias_cobro, 0) AS "garantiasCobro",
                    COALESCE(pm.gastos, 0) AS gastos,
                    COALESCE(pm.pagos_proveedor, 0) AS "pagosProveedor",
                    COALESCE(pm.garantias_devolucion, 0) AS "garantiasDevolucion",
                    COALESCE(pm.depositos, 0) AS depositos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0) AS ingresos,
                    COALESCE(pm.gastos, 0) + COALESCE(pm.pagos_proveedor, 0)
                        + COALESCE(pm.garantias_devolucion, 0) + COALESCE(pm.depositos, 0) AS egresos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0)
                        - COALESCE(pm.gastos, 0) - COALESCE(pm.pagos_proveedor, 0)
                        - COALESCE(pm.garantias_devolucion, 0) - COALESCE(pm.depositos, 0) AS neto,
                    COALESCE(cfg.orden, 999) AS orden
                FROM por_medio pm
                LEFT JOIN gen_lista_opciones o ON o.id = pm.id_medio_pago
                LEFT JOIN fin_medio_pago_config cfg ON cfg.id_medio_pago = pm.id_medio_pago
            ) r
        )
    INTO v_ventas_contado, v_ventas_credito, v_ventas_caja, v_ventas_efectivo, v_ventas_otros,
         v_cobranzas, v_cobranzas_caja, v_cobranzas_efectivo,
         v_pagos_proveedor, v_pagos_proveedor_caja,
         v_gastos_caja, v_gastos_caja_medios,
         v_depositos,
         v_garantias_cobro, v_garantias_cobro_caja,
         v_garantias_dev, v_garantias_dev_caja,
         v_efectivo_neto,
         v_por_medio
    FROM m;

    SELECT COALESCE(SUM(cc.total_importe), 0)
    INTO v_gastos_compra
    FROM com_comprobante_compra cc
    LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
    WHERE cc.estado = 1
      AND cc.fecha = p_fecha
      AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
      AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal);

    RETURN json_build_object(
        'ventasContado', v_ventas_contado,
        'ventasCredito', v_ventas_credito,
        'ventasMediosCaja', v_ventas_caja,
        'ventasEfectivo', v_ventas_efectivo,
        'ventasOtrosMedios', v_ventas_otros,
        'cobranzas', v_cobranzas,
        'cobranzasMediosCaja', v_cobranzas_caja,
        'cobranzasEfectivo', v_cobranzas_efectivo,
        'pagosProveedor', v_pagos_proveedor,
        'pagosProveedorMediosCaja', v_pagos_proveedor_caja,
        'gastosCaja', v_gastos_caja,
        'gastosCajaMediosCaja', v_gastos_caja_medios,
        'gastosCompra', v_gastos_compra,
        'gastos', v_gastos_caja + v_gastos_compra,
        'depositos', v_depositos,
        'garantiasCobro', v_garantias_cobro,
        'garantiasCobroMediosCaja', v_garantias_cobro_caja,
        'garantiasDevolucion', v_garantias_dev,
        'garantiasDevolucionMediosCaja', v_garantias_dev_caja,
        'efectivoNeto', v_efectivo_neto,
        'porMedio', v_por_medio
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_cerrar_caja_sesion (
  p_id integer,
  p_monto_efectivo_contado numeric,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_cerrar_caja_sesion (
  p_id integer,
  p_monto_efectivo_contado numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_sesion RECORD;
    v_estado_cerrada INT;
    v_totales JSON;
    v_esperado NUMERIC(14,4);
    v_diferencia NUMERIC(14,4);
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_cerrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA'
    LIMIT 1;

    SELECT s.*, est.nombre AS estado_nombre
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.id = p_id AND s.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
    END IF;

    IF UPPER(COALESCE(v_sesion.estado_nombre, '')) = 'CERRADA' THEN
        RETURN json_build_object('error', 'La caja ya está cerrada', 'registro', NULL);
    END IF;

    IF p_monto_efectivo_contado IS NULL OR p_monto_efectivo_contado < 0 THEN
        RETURN json_build_object('error', 'Indique el efectivo contado (arqueo)', 'registro', NULL);
    END IF;

    v_totales := fin_caja_calcular_totales(v_sesion.fecha, v_sesion.id_sucursal);
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0);
    v_diferencia := COALESCE(p_monto_efectivo_contado, 0) - v_esperado;

    UPDATE fin_caja_sesion
    SET id_estado = v_estado_cerrada,
        monto_efectivo_contado = p_monto_efectivo_contado,
        monto_esperado = v_esperado,
        diferencia = v_diferencia,
        totales_cierre = v_totales,
        observacion_cierre = NULLIF(TRIM(p_observacion), ''),
        fecha_cierre = NOW(),
        id_usuario_cierre = p_id_usuario,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
    VALUES (p_id, 'CERRAR', p_monto_efectivo_contado, v_diferencia, NULLIF(TRIM(p_observacion), ''), p_id_usuario);

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            v_totales AS totales
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = p_id
    ) t;

    PERFORM fin_notificar_caja_admins(p_id, 'CIERRE', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_listar_caja_sesiones (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_sucursal integer,
  p_estado_caja character varying,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.fin_listar_caja_sesiones (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_estado_caja character varying DEFAULT NULL::character varying,
  p_limite integer DEFAULT 20,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND (p_fecha_desde IS NULL OR s.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR s.fecha <= p_fecha_hasta)
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
      AND (p_estado_caja IS NULL OR UPPER(est.nombre) = UPPER(p_estado_caja));

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            ua.nombre AS "usuarioApertura",
            uc.nombre AS "usuarioCierre",
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            (SELECT COUNT(*) FROM fin_caja_sesion_evento e WHERE e.id_sesion = s.id) AS "cantidadEventos"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.estado = 1
          AND (p_fecha_desde IS NULL OR s.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR s.fecha <= p_fecha_hasta)
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
          AND (p_estado_caja IS NULL OR UPPER(est.nombre) = UPPER(p_estado_caja))
        ORDER BY s.fecha DESC, s.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 20), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_obtener_caja_sesion (p_id integer);

CREATE OR REPLACE FUNCTION public.fin_obtener_caja_sesion (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_totales JSON;
    v_fecha DATE;
    v_id_sucursal INT;
    v_fecha_cierre TIMESTAMP;
    v_totales_congelados JSON;
    v_totales_vivo JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_eventos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.fecha, s.id_sucursal, s.fecha_cierre, s.totales_cierre
    INTO v_fecha, v_id_sucursal, v_fecha_cierre, v_totales_congelados
    FROM fin_caja_sesion s WHERE s.id = p_id AND s.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Sesión no encontrada', 'registro', NULL);
    END IF;

    IF v_fecha_cierre IS NOT NULL AND v_totales_congelados IS NOT NULL THEN
        v_totales := v_totales_congelados;
    ELSE
        v_totales := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
    END IF;

    IF v_totales::JSONB->'porMedio' IS NULL THEN
        v_totales_vivo := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
        v_totales := (v_totales::JSONB || jsonb_build_object(
            'porMedio', v_totales_vivo->'porMedio',
            'efectivoNeto', v_totales_vivo->'efectivoNeto'
        ))::JSON;
    END IF;

    SELECT COALESCE(json_agg(row_to_json(g) ORDER BY g.id), '[]'::JSON) INTO v_gastos
    FROM (
        SELECT
            cg.id,
            cg.fecha,
            cg.concepto,
            cg.monto,
            cg.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cbg.alias, cbg.titular, cbg.numero_cuenta) AS "cuentaBancaria",
            cg.numero_operacion AS "numeroOperacion",
            cg.observacion
        FROM fin_caja_gasto cg
        LEFT JOIN gen_lista_opciones mp ON mp.id = cg.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cbg ON cbg.id = cg.id_cuenta_bancaria
        WHERE cg.estado = 1 AND cg.id_sesion = p_id
    ) g;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON) INTO v_depositos
    FROM (
        SELECT
            cd.id,
            cd.fecha,
            cd.monto,
            cd.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            cd.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cd.numero_operacion AS "numeroOperacion",
            cd.observacion
        FROM fin_caja_deposito cd
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cd.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = cd.id_medio_pago
        WHERE cd.estado = 1 AND cd.id_sesion = p_id
    ) d;

    SELECT COALESCE(json_agg(row_to_json(ev) ORDER BY ev."fechaHora", ev.id), '[]'::JSON) INTO v_eventos
    FROM (
        SELECT
            e.id,
            e.tipo,
            e.monto,
            e.diferencia,
            e.observacion,
            e.id_usuario AS "idUsuario",
            u.nombre AS usuario,
            e.fecha_hora AS "fechaHora"
        FROM fin_caja_sesion_evento e
        LEFT JOIN auth_usuarios u ON u.id = e.id_usuario
        WHERE e.id_sesion = p_id
    ) ev;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            ua.nombre AS "usuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            uc.nombre AS "usuarioCierre",
            v_totales AS totales,
            v_gastos AS gastos,
            v_depositos AS depositos,
            v_eventos AS eventos,
            COALESCE(s.monto_inicial, 0)
                + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0) AS "efectivoEsperado"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_obtener_libro_diario (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_cliente integer,
  p_id_sucursal integer
);

CREATE OR REPLACE FUNCTION public.fin_obtener_libro_diario (
  p_fecha_desde date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_hasta DATE;
    v_efectivo_id INT;
    v_ventas JSON;
    v_ventas_pagos JSON;
    v_cobranzas JSON;
    v_pagos_proveedor JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_garantias JSON;
    v_observaciones JSON;
    v_totales JSON;
    v_dias JSON;
    v_resumenes JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_desde IS NULL THEN
        RETURN json_build_object('error', 'fechaDesde es obligatoria', 'registro', NULL);
    END IF;

    v_hasta := COALESCE(p_fecha_hasta, p_fecha_desde);

    IF v_hasta < p_fecha_desde THEN
        RETURN json_build_object('error', 'fechaHasta no puede ser menor que fechaDesde', 'registro', NULL);
    END IF;

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_ventas
    FROM (
        SELECT
            c.id,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            c.serie,
            c.numero,
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            mp.nombre AS "medioPago",
            CASE WHEN UPPER(COALESCE(mp.nombre, '')) = 'CREDITO' THEN true ELSE false END AS "esCredito",
            c.total_importe AS "totalImporte",
            (
                SELECT string_agg(
                    COALESCE(d.descripcion, pr.nombre)
                    || CASE WHEN d.cantidad IS NOT NULL THEN ' × ' || gen_formato_cantidad(d.cantidad) ELSE '' END
                    || CASE WHEN um.nombre IS NOT NULL THEN ' ' || um.nombre ELSE '' END,
                    '; '
                )
                FROM ven_comprobante_detalle d
                LEFT JOIN pro_producto pr ON pr.id = d.id_producto
                LEFT JOIN gen_lista_opciones um ON um.id = COALESCE(d.id_unidad_medida, pr.id_unidad_medida)
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS "detalleProductos",
            EXISTS (
                SELECT 1
                FROM ven_comprobante ori
                JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
                WHERE ori.id = c.id_comprobante_origen
                  AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                  AND COALESCE(tip.descripcion, '') IN ('01', '03')
            ) AS "esConversionVsd"
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones mp ON mp.id = c.id_medio_pago
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t."idComprobante", t.item), '[]'::json)
    INTO v_ventas_pagos
    FROM (
        SELECT
            c.id AS "idComprobante",
            pg.id_pago AS "idPago",
            pg.item,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            pg.id_medio_pago AS "idMedioPago",
            COALESCE(mp.nombre, mpe.nombre) AS "medioPago",
            pg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            pg.numero_operacion AS "numeroOperacion",
            pg.monto,
            pg.origen,
            CASE
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_CREDITO')
                    THEN 'CREDITO'
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_EFECTIVO')
                    THEN 'EFECTIVO'
                ELSE 'OTROS'
            END AS grupo
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        LEFT JOIN gen_lista_opciones mp ON mp.id = pg.id_medio_pago
        LEFT JOIN gen_lista_opciones mpe ON mpe.id = v_efectivo_id
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pg.id_cuenta_bancaria
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT EXISTS (
              SELECT 1
              FROM ven_comprobante ori
              JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
              WHERE ori.id = c.id_comprobante_origen
                AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tip.descripcion, '') IN ('01', '03')
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.id), '[]'::json)
    INTO v_cobranzas
    FROM (
        SELECT
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            cu.id_tercero AS "idCliente"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes cli ON cli.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'COBRAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.clave), '[]'::json)
    INTO v_pagos_proveedor
    FROM (
        SELECT
            'P' || p.id AS clave,
            'CXP' AS origen,
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            cu.id_tercero AS "idProveedor",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ) AS proveedor,
            COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra) AS "idCompra",
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '') AS "compraSerieNumero"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN fin_cuenta pad ON pad.id = cu.id_cuenta_padre
        LEFT JOIN com_comprobante_compra cc
               ON cc.id = COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra)
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'PAGAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'C' || cc.id,
            'CONTADO',
            cc.id,
            cc.fecha,
            cc.total_importe,
            cc.id_medio_pago,
            mp.nombre,
            cc.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta),
            cc.numero_operacion,
            cc.glosa,
            NULL::INTEGER,
            cc.id_proveedor,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ),
            cc.id,
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '')
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones mp ON mp.id = cc.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cc.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cc.id_proveedor
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_cliente IS NULL OR cc.id_proveedor = p_id_cliente)
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.origen, t.id), '[]'::json)
    INTO v_gastos
    FROM (
        SELECT
            g.id,
            g.fecha,
            'CAJA'::text AS origen,
            g.concepto,
            g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            g.observacion
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN fin_caja_sesion sg ON sg.id = g.id_sesion AND sg.estado = 1
        WHERE g.estado = 1
          AND g.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sg.id_sucursal = p_id_sucursal)
        UNION ALL
        SELECT
            cc.id,
            cc.fecha,
            'COMPRA'::text AS origen,
            COALESCE(
                NULLIF(TRIM(cc.glosa), ''),
                NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), ''),
                'Gasto compra'
            ) AS concepto,
            cc.total_importe AS monto,
            NULL::integer AS "idMedioPago",
            NULL::varchar AS "medioPago",
            NULL::integer AS "idCuentaBancaria",
            NULL::varchar AS "cuentaBancaria",
            cc.glosa AS observacion
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_depositos
    FROM (
        SELECT
            d.id,
            d.fecha,
            d.monto,
            d.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            d.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            d.numero_operacion AS "numeroOperacion",
            d.observacion
        FROM fin_caja_deposito d
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = d.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = d.id_medio_pago
        LEFT JOIN fin_caja_sesion sd ON sd.id = d.id_sesion AND sd.estado = 1
        WHERE d.estado = 1
          AND d.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sd.id_sucursal = p_id_sucursal)
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_garantias
    FROM (
        SELECT
            gm.id,
            gm.fecha,
            UPPER(tm.nombre) AS tipo,
            gm.id_garantia AS "idGarantia",
            gm.monto,
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago) AS "idMedioPago",
            mp.nombre AS "medioPago",
            gm.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            gm.numero_operacion AS "numeroOperacion",
            g.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            gm.observacion
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        LEFT JOIN cli_clientes cli ON cli.id = g.id_cliente
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN gen_lista_opciones mp
               ON mp.id = COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = gm.id_cuenta_bancaria
        WHERE gm.estado = 1
          AND gm.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tm.nombre) IN ('COBRO', 'DEVOLUCION')
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_observaciones
    FROM (
        SELECT
            o.id,
            o.fecha,
            o.texto,
            u.nombre AS usuario,
            o.fecha_creacion AS "fechaCreacion"
        FROM fin_caja_observacion o
        LEFT JOIN auth_usuarios u ON u.id = o.id_usuario_creacion
        WHERE o.estado = 1
          AND o.fecha BETWEEN p_fecha_desde AND v_hasta
    ) t;

    SELECT json_build_object(
        'ventasContado', COALESCE(SUM((t.tot->>'ventasContado')::NUMERIC), 0),
        'ventasCredito', COALESCE(SUM((t.tot->>'ventasCredito')::NUMERIC), 0),
        'ventasMediosCaja', COALESCE(SUM((t.tot->>'ventasMediosCaja')::NUMERIC), 0),
        'ventasEfectivo', COALESCE(SUM((t.tot->>'ventasEfectivo')::NUMERIC), 0),
        'ventasOtrosMedios', COALESCE(SUM((t.tot->>'ventasOtrosMedios')::NUMERIC), 0),
        'cobranzas', COALESCE(SUM((t.tot->>'cobranzas')::NUMERIC), 0),
        'cobranzasMediosCaja', COALESCE(SUM((t.tot->>'cobranzasMediosCaja')::NUMERIC), 0),
        'cobranzasEfectivo', COALESCE(SUM((t.tot->>'cobranzasEfectivo')::NUMERIC), 0),
        'pagosProveedor', COALESCE(SUM((t.tot->>'pagosProveedor')::NUMERIC), 0),
        'pagosProveedorMediosCaja', COALESCE(SUM((t.tot->>'pagosProveedorMediosCaja')::NUMERIC), 0),
        'gastosCaja', COALESCE(SUM((t.tot->>'gastosCaja')::NUMERIC), 0),
        'gastosCajaMediosCaja', COALESCE(SUM((t.tot->>'gastosCajaMediosCaja')::NUMERIC), 0),
        'gastosCompra', COALESCE(SUM((t.tot->>'gastosCompra')::NUMERIC), 0),
        'gastos', COALESCE(SUM((t.tot->>'gastos')::NUMERIC), 0),
        'depositos', COALESCE(SUM((t.tot->>'depositos')::NUMERIC), 0),
        'garantiasCobro', COALESCE(SUM((t.tot->>'garantiasCobro')::NUMERIC), 0),
        'garantiasCobroMediosCaja', COALESCE(SUM((t.tot->>'garantiasCobroMediosCaja')::NUMERIC), 0),
        'garantiasDevolucion', COALESCE(SUM((t.tot->>'garantiasDevolucion')::NUMERIC), 0),
        'garantiasDevolucionMediosCaja', COALESCE(SUM((t.tot->>'garantiasDevolucionMediosCaja')::NUMERIC), 0)
    )
    INTO v_totales
    FROM (
        SELECT fin_caja_calcular_totales(d::date, p_id_sucursal) AS tot
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) t;

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.fecha), '[]'::json)
    INTO v_dias
    FROM (
        SELECT
            d::date AS fecha,
            fin_caja_calcular_totales(d::date, p_id_sucursal) AS totales
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) x;

    SELECT json_agg(row_to_json(r) ORDER BY r.orden)
    INTO v_resumenes
    FROM (
            VALUES
                ('ventas_efectivo',    'Ventas en efectivo',   'ventasPagos', 'grupo',  'EFECTIVO',
             1,  (v_totales->>'ventasEfectivo')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'EFECTIVO'), 10),
            ('ventas_otros_medios','Ventas otros medios',  'ventasPagos', 'grupo',  'OTROS',
             1,  (v_totales->>'ventasOtrosMedios')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'OTROS'), 20),
            ('ventas_credito',     'Ventas a crédito',     'ventasPagos', 'grupo',  'CREDITO',
             0,  (v_totales->>'ventasCredito')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'CREDITO'), 30),
            ('cobranzas',          'Cobranzas',            'cobranzas',   NULL,     NULL,
             1,  (v_totales->>'cobranzas')::NUMERIC,
             json_array_length(v_cobranzas), 40),
            ('garantias_cobradas', 'Garantías cobradas',   'garantias',   'tipo',   'COBRO',
             1,  (v_totales->>'garantiasCobro')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'COBRO'), 50),
            ('garantias_devueltas','Garantías devueltas',  'garantias',   'tipo',   'DEVOLUCION',
             -1, (v_totales->>'garantiasDevolucion')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'DEVOLUCION'), 60),
            ('pagos_proveedor',    'Pagos a proveedores',  'pagosProveedor', NULL,  NULL,
             -1, (v_totales->>'pagosProveedor')::NUMERIC,
             json_array_length(v_pagos_proveedor), 65),
            ('gastos',             'Gastos',               'gastos',      NULL,     NULL,
             -1, (v_totales->>'gastos')::NUMERIC,
             json_array_length(v_gastos), 70),
            ('depositos',          'Depósitos a banco',    'depositos',   NULL,     NULL,
             -1, (v_totales->>'depositos')::NUMERIC,
             json_array_length(v_depositos), 80),
            ('observaciones',      'Observaciones',        'observaciones', NULL,   NULL,
             0,  NULL::NUMERIC,
             json_array_length(v_observaciones), 90)
    ) AS r(clave, etiqueta, coleccion, "filtroCampo", "filtroValor", signo, total, cantidad, orden);

    RETURN json_build_object(
        'registro', json_build_object(
            'fechaDesde', p_fecha_desde,
            'fechaHasta', v_hasta,
            'idCliente', p_id_cliente,
            'idSucursal', p_id_sucursal,
            'ventas', v_ventas,
            'ventasPagos', v_ventas_pagos,
            'cobranzas', v_cobranzas,
            'pagosProveedor', v_pagos_proveedor,
            'gastos', v_gastos,
            'depositos', v_depositos,
            'garantias', v_garantias,
            'observaciones', v_observaciones,
            'resumenes', v_resumenes,
            'totales', v_totales,
            'dias', v_dias
        )
    );
END;
$function$;

INSERT INTO
  fin_caja_sesion_evento (
    id_sesion,
    tipo,
    monto,
    diferencia,
    observacion,
    id_usuario,
    fecha_hora
  )
SELECT
  s.id,
  v.tipo,
  v.monto,
  v.diferencia,
  v.observacion,
  v.id_usuario,
  v.fecha_hora
FROM
  fin_caja_sesion s
  CROSS JOIN LATERAL (
    VALUES
      (
        1,
        'ABRIR',
        s.monto_inicial,
        NULL::numeric,
        s.observacion_apertura,
        s.id_usuario_apertura,
        s.fecha_apertura AT TIME ZONE 'America/Lima'
      ),
      (
        2,
        'CERRAR',
        s.monto_efectivo_contado,
        s.diferencia,
        s.observacion_cierre,
        s.id_usuario_cierre,
        s.fecha_cierre AT TIME ZONE 'America/Lima'
      )
  ) AS v (
    orden,
    tipo,
    monto,
    diferencia,
    observacion,
    id_usuario,
    fecha_hora
  )
WHERE
  (
    v.tipo = 'ABRIR'
    OR s.fecha_cierre IS NOT NULL
  )
  AND NOT EXISTS (
    SELECT
      1
    FROM
      fin_caja_sesion_evento e
    WHERE
      e.id_sesion = s.id
  )
ORDER BY
  s.id,
  v.orden;

COMMIT;
