-- Convierte un JSON { error: "..." } de funciones de dominio en excepción (rollback).
CREATE OR REPLACE FUNCTION ven_raise_si_error(p_result JSON)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
BEGIN
    IF p_result IS NULL THEN
        RAISE EXCEPTION 'La operación POS no devolvió resultado';
    END IF;

    IF p_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', p_result->>'error';
    END IF;
END;
$function$;
