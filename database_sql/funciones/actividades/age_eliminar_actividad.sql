-- Function: age_eliminar_actividad
-- Baja lógica + revierte custodia EN_TRANSITO -> PENDIENTE_ENVIO
-- (mismo camino de vuelta que age_cancelar_actividad).
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
--   · EN_RUTA y REALIZADA ya no se pueden eliminar. Una actividad en ruta debe
--     cancelarse (age_cancelar_actividad) y una realizada no se deshace por
--     baja lógica: borrarlas por aquí saltaba los cierres de custodia;
--   · al revertir EN_TRANSITO se restituye el almacén de la OS, igual que
--     cancelar. Sin ello el cilindro volvía a PENDIENTE_ENVIO con
--     id_almacen NULL, es decir comprometido y en ninguna parte.

DROP FUNCTION IF EXISTS age_eliminar_actividad(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_eliminar_actividad(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
    v_id_transito   INTEGER;
    v_id_pend_envio INTEGER;
    v_id_almacen_os INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT UPPER(TRIM(ea.nombre))
    INTO v_nombre_estado
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'La actividad está EN_RUTA; cancélala para devolver los cilindros antes de eliminarla'
        );
    END IF;

    IF v_nombre_estado = 'REALIZADA' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar una actividad REALIZADA'
        );
    END IF;

    SELECT ds.id_almacen INTO v_id_almacen_os
    FROM age_actividad a
    JOIN doc_salida ds ON ds.id = a.id_doc_salida AND ds.estado = 1
    WHERE a.id = p_id;

    UPDATE age_actividad
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- ------------------------------------------------------------
    -- Camino de vuelta de la custodia: EN_TRANSITO -> PENDIENTE_ENVIO
    --
    -- Con EN_RUTA bloqueado esto solo alcanza residuales (actividades que
    -- quedaron en tránsito por flujos antiguos), pero se mantiene: eliminar no
    -- puede dejar cilindros en un viaje que ya no existe. Misma regla que
    -- cancelar, incluida la restitución del almacén de la OS.
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_transito IS NOT NULL AND v_id_pend_envio IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_pend_envio,
            id_almacen = COALESCE(v_id_almacen_os, b.id_almacen),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon = v_id_transito;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
