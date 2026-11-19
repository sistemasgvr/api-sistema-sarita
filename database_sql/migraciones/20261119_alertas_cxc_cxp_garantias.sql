-- Alertas diarias nuevas (job de las 08:00, NotificacionesLogic):
--  * CXC_VENCIDAS: cuentas por cobrar con saldo y vencimiento anterior a hoy (pedido del cliente, 15/6).
--  * CXP_POR_VENCER: cuentas por pagar vencidas o que vencen en los próximos 7 días.
--  * GARANTIAS_POR_DEVOLVER: garantías con saldo cuyo cilindro/regulador ya volvió hace 3+ días.
--  Se envían como UN resumen por día y por usuario (no una notificación por registro).
--  La alerta de P.H. también pasa a resumen diario (cambio solo en la API, sin SQL).
-- Funciones nuevas: no reemplazan nada existente. Idempotente.
BEGIN;

-- Cuentas por cobrar vencidas o por pagar próximas a vencer, para el job diario de alertas.
--  * p_tipo: 'COBRAR' → saldo > 0 con vencimiento anterior a hoy (vencidas).
--            'PAGAR'  → saldo > 0 con vencimiento hasta hoy + p_dias (incluye las ya vencidas).
--  * Solo cuentas «hoja»: las simples y las cuotas de un plan. La cabecera de un plan de cuotas
--    (numero_cuotas_total NOT NULL) no se cuenta para no duplicar el saldo.
DROP FUNCTION IF EXISTS public.fin_listar_cuentas_alerta_notificar (p_tipo character varying, p_dias integer, p_fecha date);

CREATE OR REPLACE FUNCTION public.fin_listar_cuentas_alerta_notificar (
  p_tipo character varying,
  p_dias integer DEFAULT 7,
  p_fecha date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha DATE;
    v_tipo VARCHAR;
    v_id_tipo INTEGER;
    v_hasta DATE;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_tipo := UPPER(TRIM(COALESCE(p_tipo, '')));

    IF v_tipo NOT IN ('COBRAR', 'PAGAR') THEN
        RETURN json_build_object('registros', '[]'::JSON, 'error', 'Tipo de cuenta inválido');
    END IF;

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = v_tipo
    LIMIT 1;

    IF v_id_tipo IS NULL THEN
        RETURN json_build_object('registros', '[]'::JSON);
    END IF;

    -- COBRAR: solo vencidas (antes de hoy). PAGAR: vencidas y las que vencen en p_dias.
    v_hasta := CASE WHEN v_tipo = 'COBRAR' THEN v_fecha - 1
                    ELSE v_fecha + GREATEST(COALESCE(p_dias, 7), 0) END;

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha_vencimiento, t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            fc.id,
            fc.fecha_vencimiento,
            json_build_object(
                'id', fc.id,
                'id_tercero', fc.id_tercero,
                'tercero', COALESCE(
                    NULLIF(TRIM(ter.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                    fc.tercero_nombre,
                    'Tercero #' || fc.id
                ),
                'numero_comprobante', COALESCE(fc.numero_comprobante, fc.descripcion),
                'numero_cuota', fc.numero_cuota,
                'fecha_vencimiento', fc.fecha_vencimiento,
                'dias', (v_fecha - fc.fecha_vencimiento),
                'saldo', ROUND(COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)), 2)
            ) AS row_data
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.estado = 1
          AND fc.id_tipo_cuenta = v_id_tipo
          AND fc.numero_cuotas_total IS NULL
          AND fc.fecha_vencimiento IS NOT NULL
          AND fc.fecha_vencimiento <= v_hasta
          AND COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)) > 0.005
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;

-- Garantías con saldo cuyo envase ya volvió, para el job diario de alertas.
--  * Préstamo: el cilindro de la garantía (id_prestamo_detalle) tiene fecha_devolucion y no terminó
--    perdido, robado, vendido ni facturado (en esos casos la garantía no se devuelve).
--  * Alquiler: el regulador tiene fecha_devolucion_regulador.
--  * Solo si pasaron al menos p_dias días desde la devolución, para no alertar el mismo día en que
--    el mostrador todavía está reembolsando.
--  Criterio conservador a propósito: una garantía sin vínculo a un detalle o alquiler no se alerta.
DROP FUNCTION IF EXISTS public.ven_listar_garantias_por_devolver_notificar (p_dias integer, p_fecha date);

CREATE OR REPLACE FUNCTION public.ven_listar_garantias_por_devolver_notificar (
  p_dias integer DEFAULT 3,
  p_fecha date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha DATE;
    v_limite DATE;
    v_registros JSON;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_fecha := COALESCE(p_fecha, CURRENT_DATE);
    v_limite := v_fecha - GREATEST(COALESCE(p_dias, 3), 0);

    SELECT COALESCE(json_agg(t.row_data ORDER BY t.fecha_devolucion, t.id), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            g.id,
            COALESCE(pd.fecha_devolucion, a.fecha_devolucion_regulador) AS fecha_devolucion,
            json_build_object(
                'id', g.id,
                'id_cliente', g.id_cliente,
                'nombre_cliente', COALESCE(
                    NULLIF(TRIM(c.razon_social), ''),
                    TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno))
                ),
                'id_prestamo', g.id_prestamo,
                'id_alquiler', g.id_alquiler,
                'fecha_devolucion', COALESCE(pd.fecha_devolucion, a.fecha_devolucion_regulador),
                'dias', v_fecha - COALESCE(pd.fecha_devolucion, a.fecha_devolucion_regulador),
                'saldo', ROUND(g.monto_saldo, 2)
            ) AS row_data
        FROM ven_garantia g
        LEFT JOIN bal_prestamo_detalle pd ON pd.id = g.id_prestamo_detalle AND pd.estado = 1
        LEFT JOIN gen_lista_opciones epd ON epd.id = pd.id_estado
        LEFT JOIN bal_alquiler a ON a.id = g.id_alquiler AND a.estado = 1
        LEFT JOIN cli_clientes c ON c.id = g.id_cliente
        WHERE g.estado = 1
          AND g.monto_saldo > 0.005
          AND (
                (pd.id IS NOT NULL
                 AND pd.fecha_devolucion IS NOT NULL
                 AND COALESCE(epd.nombre, '') NOT IN ('PERDIDO', 'ROBO', 'VENDIDO', 'FACTURADO'))
             OR (g.id_prestamo_detalle IS NULL AND a.id IS NOT NULL AND a.fecha_devolucion_regulador IS NOT NULL)
          )
          AND COALESCE(pd.fecha_devolucion, a.fecha_devolucion_regulador) <= v_limite
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;

COMMIT;
