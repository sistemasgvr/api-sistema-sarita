-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_prestamo_cerrar_si_completo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_prestamo_cerrar_si_completo(p_id_prestamo integer, p_fecha date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_prestamo_cerrar_si_completo(p_id_prestamo integer, p_fecha date DEFAULT CURRENT_DATE, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_pendientes INTEGER;
    v_id_estado_cerrado INTEGER;
BEGIN
    IF p_id_prestamo IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_prestamo_detalle
    WHERE id_prestamo = p_id_prestamo
      AND estado = 1
      AND fecha_devolucion IS NULL;

    IF COALESCE(v_pendientes, 0) > 0 THEN
        RETURN;
    END IF;

    SELECT lo.id INTO v_id_estado_cerrado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'CERRADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_prestamo
    SET
        fecha_retorno_real = COALESCE(fecha_retorno_real, COALESCE(p_fecha, CURRENT_DATE)),
        id_estado = COALESCE(v_id_estado_cerrado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_prestamo
      AND estado = 1;
END;
$function$;
