-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: age_cambiar_estado_actividad_realizada
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_cambiar_estado_actividad_realizada(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_cambiar_estado_actividad_realizada(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_realizada INTEGER;
    v_id_estado_actual INTEGER;
    v_nombre_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_id_estado_realizada
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'REALIZADA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_realizada IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'No se encontró el estado REALIZADA en EstadoActividad.');
    END IF;

    SELECT a.id_estado_actividad, UPPER(TRIM(t.nombre))
    INTO v_id_estado_actual, v_nombre_tipo
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones t ON t.id = a.id_tipo_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF COALESCE(v_nombre_tipo, '') = 'REPARTO' THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'El reparto se cierra con Culminar entrega, no marcando realizada a mano.'
        );
    END IF;

    IF COALESCE(v_nombre_tipo, '') = 'RECOJO' THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'El recojo se cierra con Culminar recojo (elige almacén destino), no marcando realizada a mano.'
        );
    END IF;

    IF v_id_estado_actual = v_id_estado_realizada THEN
        RETURN json_build_object('registro', NULL, 'error', 'La actividad ya se encuentra marcada como realizada.');
    END IF;

    UPDATE age_actividad
    SET 
        id_estado_actividad = v_id_estado_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
