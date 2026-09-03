-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_caja_assert_abierta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS fin_caja_assert_abierta(p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_caja_assert_abierta(p_fecha date, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_pendiente_fecha DATE;
    v_hoy DATE;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_hoy := CURRENT_DATE;

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

    IF v_estado = 'ABIERTA' THEN
        -- Caja de un día anterior aún abierta: bloquear ventas/movimientos.
        -- El cierre (arqueo) no usa este assert.
        IF p_fecha < v_hoy THEN
            RETURN format(
                'La caja del %s quedó abierta. Debes cerrarla (arqueo) en Ventas → Caja antes de registrar más operaciones, y luego abrir la caja de hoy.',
                to_char(p_fecha, 'DD/MM/YYYY')
            );
        END IF;
        RETURN NULL;
    END IF;

    IF v_estado = 'CERRADA' THEN
        RETURN 'La caja de esta fecha ya está cerrada. No se pueden registrar más operaciones.';
    END IF;

    IF v_estado IS NOT NULL THEN
        RETURN 'La sesión de caja no está abierta.';
    END IF;

    -- Sin sesión en p_fecha: ¿hay alguna ABIERTA de otro día?
    SELECT s.fecha INTO v_pendiente_fecha
    FROM fin_caja_sesion s
    INNER JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND UPPER(est.nombre) = 'ABIERTA'
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
      AND s.fecha < v_hoy
    ORDER BY s.fecha ASC
    LIMIT 1;

    IF v_pendiente_fecha IS NOT NULL THEN
        RETURN format(
            'Hay una caja sin cerrar del %s. Ciérrala en Ventas → Caja (arqueo) antes de abrir o operar la de hoy.',
            to_char(v_pendiente_fecha, 'DD/MM/YYYY')
        );
    END IF;

    RETURN 'No hay caja abierta para esta fecha. Abre la caja en Ventas → Caja antes de continuar.';
END;
$function$;
