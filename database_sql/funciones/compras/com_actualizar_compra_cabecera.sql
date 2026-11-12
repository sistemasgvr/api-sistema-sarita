-- Actualiza compra cabecera
DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying
);

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric
);

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric,
  p_fecha date,
  p_fecha_emision date,
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying
);

-- p_fecha es la FECHA DE GASTO: cambiarla mueve el pago a la caja de la nueva fecha (debe estar abierta);
-- si la caja de origen ya estaba cerrada se recalcula su arqueo. Comprobante (tipo, serie, número, emisión)
-- se completa sin tocar la caja. NULL = conservar; para vaciar: p_serie/p_numero '', p_id_tipo_comprobante 0,
-- p_quitar_fecha_emision TRUE (la compra vuelve a "pendiente de comprobante").
CREATE OR REPLACE FUNCTION public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_categoria_gasto integer DEFAULT NULL::integer,
  p_declarar_sunat boolean DEFAULT NULL::boolean,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_fecha_vencimiento_cxp date DEFAULT NULL::date,
  p_cuotas_cxp jsonb DEFAULT NULL::jsonb,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_porcentaje_igv numeric DEFAULT NULL::numeric,
  p_fecha date DEFAULT NULL::date,
  p_fecha_emision date DEFAULT NULL::date,
  p_id_tipo_comprobante integer DEFAULT NULL::integer,
  p_serie character varying DEFAULT NULL::character varying,
  p_numero character varying DEFAULT NULL::character varying,
  p_quitar_fecha_emision boolean DEFAULT FALSE
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_pago_antes JSONB;
    v_pago_despues JSONB;
    v_tenia_cxp BOOLEAN;
    v_err TEXT;
    v_porcentaje_igv NUMERIC(5,2);
    v_compra RECORD;
    v_mueve_fecha BOOLEAN := FALSE;
    v_id_sesion_origen INTEGER;
    v_arqueo JSON;
    v_observacion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_emision IS NOT NULL AND p_fecha_emision > CURRENT_DATE THEN
        RETURN json_build_object('error', 'La fecha de emisión no puede ser posterior a hoy', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante AND estado = 1) THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO') THEN
        RETURN json_build_object('error', 'El medio de pago de la compra no puede ser crédito: para una compra al crédito elige la condición de pago.', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL THEN
        v_err := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
        IF v_err IS NOT NULL THEN
            RETURN json_build_object('error', v_err, 'registro', NULL);
        END IF;
    END IF;

    IF p_porcentaje_igv IS NOT NULL THEN
        v_porcentaje_igv := ROUND(p_porcentaje_igv, 2);
        IF v_porcentaje_igv < 0 OR v_porcentaje_igv > 100 THEN
            RETURN json_build_object('error', 'El porcentaje de IGV debe estar entre 0 y 100', 'registro', NULL);
        END IF;
    END IF;

    SELECT id, fecha, id_sucursal, total_importe INTO v_compra
    FROM com_comprobante_compra WHERE id = p_id_comprobante;
    v_mueve_fecha := p_fecha IS NOT NULL AND p_fecha <> v_compra.fecha;

    v_pago_antes := com_pago_caja_compra(p_id_comprobante);
    v_tenia_cxp := EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    );

    UPDATE com_comprobante_compra
    SET glosa               = COALESCE(p_glosa, glosa),
        id_condicion_pago   = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_categoria_gasto  = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        id_medio_pago       = COALESCE(p_id_medio_pago, id_medio_pago),
        id_cuenta_bancaria  = CASE WHEN p_id_medio_pago IS NOT NULL THEN p_id_cuenta_bancaria ELSE id_cuenta_bancaria END,
        numero_operacion    = CASE WHEN p_id_medio_pago IS NOT NULL THEN NULLIF(TRIM(p_numero_operacion), '') ELSE numero_operacion END,
        porcentaje_igv      = COALESCE(v_porcentaje_igv, porcentaje_igv),
        fecha               = COALESCE(p_fecha, fecha),
        fecha_emision       = CASE WHEN COALESCE(p_quitar_fecha_emision, FALSE) THEN NULL
                                   ELSE COALESCE(p_fecha_emision, fecha_emision) END,
        id_tipo_comprobante = CASE WHEN p_id_tipo_comprobante = 0 THEN NULL
                                   ELSE COALESCE(p_id_tipo_comprobante, id_tipo_comprobante) END,
        serie               = CASE WHEN p_serie IS NULL THEN serie ELSE NULLIF(TRIM(p_serie), '') END,
        numero              = CASE WHEN p_numero IS NULL THEN numero ELSE NULLIF(TRIM(p_numero), '') END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

    IF v_porcentaje_igv IS NOT NULL THEN
        UPDATE com_comprobante_compra
        SET sub_total = ROUND(COALESCE(total_importe, 0) / (1 + v_porcentaje_igv / 100), 4),
            igv       = COALESCE(total_importe, 0) - ROUND(COALESCE(total_importe, 0) / (1 + v_porcentaje_igv / 100), 4)
        WHERE id = p_id_comprobante;
    END IF;

    PERFORM com_sincronizar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    IF EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    ) THEN
        UPDATE com_comprobante_compra
        SET id_medio_pago = NULL, id_cuenta_bancaria = NULL, numero_operacion = NULL
        WHERE id = p_id_comprobante;
    ELSIF v_tenia_cxp AND EXISTS (
        SELECT 1 FROM com_comprobante_compra
        WHERE id = p_id_comprobante AND id_medio_pago IS NULL AND COALESCE(total_importe, 0) > 0
    ) THEN
        RAISE EXCEPTION 'Indica el medio de pago: al pasar la compra a contado se paga en el momento.';
    END IF;

    v_pago_despues := com_pago_caja_compra(p_id_comprobante);
    IF v_mueve_fecha
       AND v_pago_antes->'idMedioPago' IS NOT DISTINCT FROM v_pago_despues->'idMedioPago'
       AND v_pago_antes->'monto' IS NOT DISTINCT FROM v_pago_despues->'monto' THEN
        -- Solo se mueve la fecha de gasto: basta la caja de destino abierta (decisión de negocio);
        -- la de origen puede estar cerrada y su arqueo se recalcula abajo.
        v_err := com_assert_caja_compra(NULL, v_pago_despues);
    ELSE
        -- Cambios de medio/monto (con o sin cambio de fecha) validan origen y destino como siempre.
        v_err := com_assert_caja_compra(v_pago_antes, v_pago_despues);
    END IF;
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;

    IF v_mueve_fecha AND COALESCE((v_pago_antes->>'afectaCaja')::BOOLEAN, FALSE) THEN
        SELECT s.id INTO v_id_sesion_origen
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.fecha = v_compra.fecha
          AND COALESCE(s.id_sucursal, 0) = COALESCE(v_compra.id_sucursal, 0)
        ORDER BY s.id DESC
        LIMIT 1;

        IF v_id_sesion_origen IS NOT NULL THEN
            -- NULL si la caja de origen sigue abierta: sus totales se recalculan solos en vivo.
            v_arqueo := fin_caja_recalcular_arqueo(v_id_sesion_origen, p_id_usuario_auditoria);

            SELECT 'Compra ' || COALESCE(c.serie || '-' || c.numero, '#' || c.id)
                   || ' movida al ' || to_char(p_fecha, 'DD/MM/YYYY')
            INTO v_observacion
            FROM com_comprobante_compra c WHERE c.id = p_id_comprobante;

            IF v_arqueo IS NOT NULL THEN
                v_observacion := v_observacion || ' · arqueo recalculado, esperado '
                    || ROUND(COALESCE((v_arqueo->>'montoEsperadoAnterior')::NUMERIC, 0), 2)
                    || ' → ' || ROUND((v_arqueo->>'montoEsperado')::NUMERIC, 2);
            END IF;

            INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
            VALUES (
                v_id_sesion_origen, 'AJUSTE_COMPRA', (v_pago_antes->>'monto')::NUMERIC,
                (v_arqueo->>'diferencia')::NUMERIC, LEFT(v_observacion, 500), p_id_usuario_auditoria
            );
        END IF;
    END IF;

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;
