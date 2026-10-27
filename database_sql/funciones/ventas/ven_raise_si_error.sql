-- Lanza una excepción si el resultado JSON es nulo o trae error
DROP FUNCTION IF EXISTS public.ven_raise_si_error (p_result json);

CREATE OR REPLACE FUNCTION public.ven_raise_si_error (p_result json) RETURNS void LANGUAGE plpgsql AS $function$
BEGIN
    IF p_result IS NULL THEN
        RAISE EXCEPTION 'La operación POS no devolvió resultado';
    END IF;

    IF p_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', p_result->>'error';
    END IF;
END;
$function$;
