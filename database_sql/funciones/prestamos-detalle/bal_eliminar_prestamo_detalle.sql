CREATE OR REPLACE FUNCTION bal_eliminar_prestamo_detalle(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_prestamo INTEGER;
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_id_cliente INTEGER;
    v_fecha_devolucion DATE;
    v_retorno JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        p.id_almacen,
        p.id_cliente
    INTO
        v_id_prestamo,
        v_id_balon,
        v_fecha_devolucion,
        v_id_almacen,
        v_id_cliente
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE bal_prestamo_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si seguía pendiente, libera custodia (sin forzar vacío: es anulación, no devolución física).
    IF v_id_balon IS NOT NULL AND v_fecha_devolucion IS NULL THEN
        IF v_id_almacen IS NULL THEN
            SELECT id INTO v_id_almacen FROM gen_almacen WHERE estado = 1 ORDER BY id LIMIT 1;
        END IF;

        v_retorno := bal_prestamo_aplicar_retorno_cilindro(
            v_id_balon,
            v_id_prestamo,
            v_id_cliente,
            v_id_almacen,
            NULL,
            'Anulación de detalle de préstamo',
            p_id_usuario_auditoria,
            TRUE
        );

        IF v_retorno->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_retorno->>'error';
        END IF;

        PERFORM bal_prestamo_cerrar_si_completo(
            v_id_prestamo,
            CURRENT_DATE,
            p_id_usuario_auditoria
        );
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
