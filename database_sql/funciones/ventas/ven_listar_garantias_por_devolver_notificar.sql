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
