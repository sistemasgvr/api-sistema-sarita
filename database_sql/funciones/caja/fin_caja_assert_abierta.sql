-- Devuelve NULL si hay sesión ABIERTA para fecha/sucursal; si no, mensaje de error.
CREATE OR REPLACE FUNCTION fin_caja_assert_abierta(
    p_fecha DATE,
    p_id_sucursal INT DEFAULT NULL
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_estado VARCHAR;
BEGIN
    IF p_fecha IS NULL THEN
        RETURN 'La fecha es obligatoria para validar la caja';
    END IF;

    SELECT UPPER(est.nombre) INTO v_estado
    FROM fin_caja_sesion s
    INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    ORDER BY s.id DESC
    LIMIT 1;

    IF v_estado IS NULL THEN
        RETURN 'No hay caja abierta para esta fecha. Abre la caja en Ventas / Caja antes de continuar.';
    END IF;

    IF v_estado = 'CERRADA' THEN
        RETURN 'La caja de esta fecha ya está cerrada. No se pueden registrar más operaciones.';
    END IF;

    IF v_estado <> 'ABIERTA' THEN
        RETURN 'La sesión de caja no está abierta.';
    END IF;

    RETURN NULL;
END;
$function$;
