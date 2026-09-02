-- Capacidad de gas aún disponible en un cilindro LLENO (residual o capacidad del tipo).
CREATE OR REPLACE FUNCTION bal_capacidad_disponible_balon(p_id_balon INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_disponible NUMERIC;
BEGIN
    SELECT COALESCE(tb.capacidad, 0)
    INTO v_disponible
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon
      AND b.estado = 1;

    RETURN COALESCE(v_disponible, 0);
END;
$function$;
