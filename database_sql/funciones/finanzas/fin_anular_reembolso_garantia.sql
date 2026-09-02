-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_anular_reembolso_garantia
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.667Z
DROP FUNCTION IF EXISTS fin_anular_reembolso_garantia(p_id integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_anular_reembolso_garantia(p_id integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia    fin_garantia%ROWTYPE;
    v_id_activa   INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia FROM fin_garantia WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La garantía no existe o está inactiva');
    END IF;

    IF v_garantia.fecha_reembolso IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta garantía aún no tiene reembolso registrado; nada que anular.');
    END IF;

    SELECT glo.id INTO v_id_activa
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = 'ACTIVA'
    LIMIT 1;

    UPDATE fin_garantia SET
        fecha_reembolso       = NULL,
        id_medio_reembolso    = NULL,
        observacion_reembolso = NULL,
        id_usuario_reembolso  = NULL,
        id_estado             = COALESCE(v_id_activa, id_estado),
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion    = NOW()
    WHERE id = p_id;

    RETURN json_build_object('registro', json_build_object('id', p_id, 'estado_texto', 'ACTIVA'));
END;
$function$
