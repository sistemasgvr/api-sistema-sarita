-- Si la caja de una fecha y sucursal está CERRADA recalcula su arqueo y lo anota en la bitácora (operaciones sin efectivo)
DROP FUNCTION IF EXISTS public.fin_caja_refrescar_cerrada (
  p_fecha date,
  p_id_sucursal integer,
  p_monto numeric,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_caja_refrescar_cerrada (
  p_fecha date,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_monto numeric DEFAULT NULL::numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_sesion INTEGER;
    v_arqueo JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN NULL;
    END IF;

    -- Misma sesión que mira fin_caja_assert_abierta: la última de esa fecha y sucursal.
    SELECT s.id INTO v_id_sesion
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    ORDER BY s.id DESC
    LIMIT 1;

    IF v_id_sesion IS NULL THEN
        RETURN NULL;
    END IF;

    -- NULL si la caja sigue abierta: sus totales se calculan en vivo.
    v_arqueo := fin_caja_recalcular_arqueo(v_id_sesion, p_id_usuario);
    IF v_arqueo IS NULL THEN
        RETURN NULL;
    END IF;

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
    VALUES (
        v_id_sesion,
        'AJUSTE_SIN_EFECTIVO',
        ROUND(p_monto, 2),
        (v_arqueo->>'diferencia')::NUMERIC,
        LEFT(COALESCE(NULLIF(TRIM(p_observacion), ''), 'Operación sin efectivo registrada con la caja cerrada'), 500),
        p_id_usuario
    );

    RETURN json_build_object(
        'idSesion', v_id_sesion,
        'montoEsperado', (v_arqueo->>'montoEsperado')::NUMERIC,
        'diferencia', (v_arqueo->>'diferencia')::NUMERIC
    );
END;
$function$;
