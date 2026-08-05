-- Capacidad de gas aún disponible en un cilindro LLENO (residual o capacidad del tipo).
CREATE OR REPLACE FUNCTION bal_capacidad_disponible_balon(p_id_balon INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_disponible NUMERIC;
BEGIN
    SELECT CASE
        WHEN COALESCE(ec.nombre, '') = 'LLENO' THEN
            COALESCE(b.capacidad_restante, tb.capacidad, 0)
        ELSE 0
    END
    INTO v_disponible
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    LEFT JOIN gen_lista_opciones ec ON ec.id = b.id_estado_contenido
    WHERE b.id = p_id_balon
      AND b.estado = 1;

    RETURN COALESCE(v_disponible, 0);
END;
$function$;
