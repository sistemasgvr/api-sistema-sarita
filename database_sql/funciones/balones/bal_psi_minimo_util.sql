CREATE OR REPLACE FUNCTION bal_psi_minimo_util()
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
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
