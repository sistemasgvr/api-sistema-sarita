CREATE OR REPLACE FUNCTION bal_sync_ph_desde_recarga(
    p_id_movimiento_recarga INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_row RECORD;
BEGIN
    SELECT
        r.id,
        r.id_balon,
        r.fecha_prueba_hidrostatica,
        r.observacion
    INTO v_row
    FROM bal_movimiento_recarga r
    WHERE r.id = p_id_movimiento_recarga AND r.estado = 1;

    IF NOT FOUND OR v_row.fecha_prueba_hidrostatica IS NULL THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_balon_ph_historial
        WHERE id_movimiento_recarga = p_id_movimiento_recarga AND estado = 1
    ) THEN
        RETURN;
    END IF;

    PERFORM bal_registrar_ph_historial(
        v_row.id_balon,
        v_row.fecha_prueba_hidrostatica,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        p_id_movimiento_recarga,
        NULLIF(TRIM(COALESCE(v_row.observacion, '')), ''),
        p_id_usuario_auditoria
    );
END;
$function$;
