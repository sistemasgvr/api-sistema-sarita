-- Elimina una línea (solo si la compra aún no tiene
-- movimientos de inventario en NINGUNA de sus líneas)
CREATE OR REPLACE FUNCTION com_eliminar_compra_detalle(
    p_id_detalle             INTEGER,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id, d.id_comprobante, d.afecta_stock
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    WHERE d.id = p_id_detalle AND d.estado = 1 AND c.estado = 1;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_detalle);
    END IF;

    -- Regla 1: si la compra (cualquiera de sus líneas, no solo esta)
    -- ya generó movimientos de inventario, se bloquea toda eliminación.
    IF com_tiene_movimientos_inventario(v_detalle.id_comprobante) THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id_detalle,
            'error', 'Esta compra ya generó movimientos de inventario y no admite modificación parcial. Anule la compra completa y registre una nueva referenciándola.'
        );
    END IF;

    -- Llegado a este punto, v_detalle.afecta_stock siempre es FALSE
    -- (si fuera TRUE, la comprobación anterior ya habría bloqueado),
    -- así que no hace falta revertir ningún movimiento de stock.
    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_detalle);
END;
$function$;