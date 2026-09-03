-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_eliminar_garantia
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
DROP FUNCTION IF EXISTS ven_eliminar_garantia(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION ven_eliminar_garantia(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia RECORD;
    v_es_manual BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia
    FROM ven_garantia
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'La garantía no existe o ya está inactiva'
        );
    END IF;

    v_es_manual :=
        v_garantia.id_prestamo IS NULL
        AND v_garantia.id_alquiler IS NULL
        AND NOT EXISTS (
            SELECT 1
            FROM ven_garantia_movimiento gm
            WHERE gm.id_garantia = v_garantia.id
              AND gm.estado = 1
              AND gm.id_comprobante IS NOT NULL
        );

    IF NOT v_es_manual THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'Solo se pueden eliminar garantías manuales'
        );
    END IF;

    IF COALESCE(v_garantia.monto_devuelto, 0) > 0 THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede eliminar una garantía con devoluciones. Anule primero los reembolsos.'
        );
    END IF;

    UPDATE ven_garantia_movimiento
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_garantia = p_id AND estado = 1;

    UPDATE ven_garantia
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object('eliminado', true, 'id', p_id);
END;
$function$;
