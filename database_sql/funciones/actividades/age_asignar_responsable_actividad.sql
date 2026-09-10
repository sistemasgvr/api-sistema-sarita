-- Function: age_asignar_responsable_actividad
-- Source: migraciones/20260909_age_responsable_apoyo.sql

DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(p_id integer, p_id_usuario_auditoria integer, p_id_trabajador_responsable integer);
DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(integer, integer, integer, integer, boolean);

CREATE OR REPLACE FUNCTION age_asignar_responsable_actividad(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_id_trabajador_apoyo integer DEFAULT NULL::integer,
    p_liberar boolean DEFAULT FALSE
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF COALESCE(p_liberar, FALSE) THEN
        SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
        FROM age_actividad a
        LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
        WHERE a.id = p_id AND a.estado = 1;

        -- Liberar en ruta dejaria cilindros EN_TRANSITO sin responsable.
        IF COALESCE(v_nombre_estado, '') = 'EN_RUTA' THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'Cancela la actividad o culmina antes de liberar'
            );
        END IF;

        UPDATE age_actividad
        SET id_trabajador_responsable = NULL,
            id_trabajador_apoyo = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id AND estado = 1;

        RETURN age_obtener_actividad(p_id);
    END IF;

    -- Sin esto, "Tomar actividad" desde un usuario sin ficha de trabajador
    -- dejaba la actividad sin asignar y devolvia exito.
    IF p_id_trabajador_responsable IS NULL THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No hay un trabajador que asignar: tu usuario no tiene ficha de trabajador vinculada.'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM tra_trabajadores t
        WHERE t.id = p_id_trabajador_responsable AND t.estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El responsable debe ser un trabajador vigente.');
    END IF;

    IF p_id_trabajador_apoyo IS NOT NULL THEN
        IF p_id_trabajador_apoyo = p_id_trabajador_responsable THEN
            RETURN json_build_object('registro', NULL, 'error', 'El apoyo no puede ser la misma persona que el responsable.');
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM tra_trabajadores t
            WHERE t.id = p_id_trabajador_apoyo AND t.estado = 1
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'El apoyo debe ser un trabajador vigente.');
        END IF;
    END IF;

    UPDATE age_actividad
    SET id_trabajador_responsable = p_id_trabajador_responsable,
        id_trabajador_apoyo = p_id_trabajador_apoyo,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
