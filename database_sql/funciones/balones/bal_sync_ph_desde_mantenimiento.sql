-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_sync_ph_desde_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.608Z
DROP FUNCTION IF EXISTS bal_sync_ph_desde_mantenimiento(p_id_mantenimiento integer, p_id_usuario_auditoria integer, p_vigencia_anios integer, p_id_organo_inspector integer, p_organo_inspector_no_aplica boolean, p_numero_certificado character varying);

CREATE OR REPLACE FUNCTION bal_sync_ph_desde_mantenimiento(p_id_mantenimiento integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_vigencia_anios integer DEFAULT NULL::integer, p_id_organo_inspector integer DEFAULT NULL::integer, p_organo_inspector_no_aplica boolean DEFAULT NULL::boolean, p_numero_certificado character varying DEFAULT NULL::character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_row RECORD;
BEGIN
    SELECT
        m.id,
        m.id_balon,
        m.fecha_salida,
        m.descripcion,
        m.observacion,
        tm.nombre AS nombre_tipo
    INTO v_row
    FROM bal_mantenimiento m
    LEFT JOIN gen_lista_opciones tm ON m.id_tipo_mantenimiento = tm.id
    WHERE m.id = p_id_mantenimiento AND m.estado = 1;

    IF NOT FOUND OR v_row.fecha_salida IS NULL THEN
        RETURN;
    END IF;

    IF UPPER(COALESCE(v_row.nombre_tipo, '')) NOT IN ('PRUEBA_HIDROSTATICA', 'RECERTIFICACION') THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_balon_ph_historial
        WHERE id_mantenimiento = p_id_mantenimiento AND estado = 1
    ) THEN
        RETURN;
    END IF;

    PERFORM bal_registrar_ph_historial(
        v_row.id_balon,
        v_row.fecha_salida,
        p_vigencia_anios,
        p_id_organo_inspector,
        COALESCE(p_organo_inspector_no_aplica, FALSE),
        p_numero_certificado,
        p_id_mantenimiento,
        NULL,
        NULLIF(TRIM(COALESCE(v_row.descripcion, v_row.observacion, '')), ''),
        p_id_usuario_auditoria
    );
END;
$function$
