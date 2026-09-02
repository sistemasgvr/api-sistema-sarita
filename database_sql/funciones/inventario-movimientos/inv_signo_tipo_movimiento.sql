-- Signo canónico de TipoMovInvUnificado.
-- -1 = salida (descuenta stock origen)
--  1 = entrada (aumenta stock origen)
--  0 = traslado (sale origen / entra destino; o movimiento de custodia sin stock de producto)
-- NULL = AJUSTE (lo resuelve p_sentido_ajuste) o tipo desconocido
DROP FUNCTION IF EXISTS inv_signo_tipo_movimiento(integer);

CREATE OR REPLACE FUNCTION inv_signo_tipo_movimiento(p_id_tipo_movimiento integer)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_nombre VARCHAR;
BEGIN
    IF p_id_tipo_movimiento IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT UPPER(TRIM(nombre)) INTO v_nombre
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_movimiento;

    IF v_nombre IS NULL THEN
        RETURN NULL;
    END IF;

    IF v_nombre IN ('TRASLADO', 'TRASLADO_LIMA') THEN
        RETURN 0;
    END IF;

    IF v_nombre = 'AJUSTE' THEN
        RETURN NULL;
    END IF;

    IF v_nombre IN (
        'SALIDA',
        'SALIDA_VENTA',
        'SALIDA_PRESTAMO',
        'SALIDA_ALQUILER',
        'SALIDA_MANTENIMIENTO',
        'SALIDA_PLANTA_EXTERNA',
        'SALIDA_ENTREGA_CLIENTE',
        'RECARGA_CLIENTE',
        'PRESTAMO',
        'ALQUILER',
        'MERMA',
        'DESPACHO'
    ) OR v_nombre LIKE 'SALIDA_%' THEN
        RETURN -1;
    END IF;

    IF v_nombre IN (
        'INGRESO',
        'ENTRADA_DEVOLUCION',
        'ENTRADA_MANTENIMIENTO',
        'ENTRADA_LLENADO',
        'ENTRADA_PLANTA_EXTERNA',
        'RETORNO_LIMA',
        'RETORNO_PRESTAMO',
        'DEVOLUCION'
    ) OR v_nombre LIKE 'ENTRADA_%' OR v_nombre LIKE 'RETORNO_%' THEN
        RETURN 1;
    END IF;

    RETURN NULL;
END;
$function$;
