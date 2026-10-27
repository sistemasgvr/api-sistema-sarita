-- Devuelve la presión mínima útil (PSI) configurada en la empresa, 100 por defecto
DROP FUNCTION IF EXISTS public.bal_psi_minimo_util ();

CREATE OR REPLACE FUNCTION public.bal_psi_minimo_util () RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_psi NUMERIC;
BEGIN
    SELECT e.psi_minimo_util
    INTO v_psi
    FROM gen_empresa e
    WHERE e.estado = 1
    ORDER BY e.id
    LIMIT 1;

    RETURN COALESCE(v_psi, 100);
END;
$function$;
