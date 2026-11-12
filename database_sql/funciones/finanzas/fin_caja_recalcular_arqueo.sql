-- Recalcula el arqueo de una caja CERRADA con los totales en vivo de su día (el efectivo contado no cambia)
DROP FUNCTION IF EXISTS public.fin_caja_recalcular_arqueo (p_id_sesion integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.fin_caja_recalcular_arqueo (
  p_id_sesion integer,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_sesion RECORD;
    v_totales JSON;
    v_esperado NUMERIC(14,4);
    v_diferencia NUMERIC(14,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.*, UPPER(COALESCE(est.nombre, '')) AS estado_nombre
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.id = p_id_sesion AND s.estado = 1;

    IF NOT FOUND OR v_sesion.estado_nombre <> 'CERRADA' THEN
        RETURN NULL;
    END IF;

    -- Misma fórmula que fin_cerrar_caja_sesion
    v_totales := fin_caja_calcular_totales(v_sesion.fecha, v_sesion.id_sucursal);
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0);
    v_diferencia := COALESCE(v_sesion.monto_efectivo_contado, 0) - v_esperado;

    UPDATE fin_caja_sesion
    SET monto_esperado = v_esperado,
        diferencia = v_diferencia,
        totales_cierre = v_totales,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id_sesion;

    RETURN json_build_object(
        'montoEsperadoAnterior', v_sesion.monto_esperado,
        'montoEsperado', v_esperado,
        'diferencia', v_diferencia
    );
END;
$function$;
