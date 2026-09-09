-- ============================================================
-- Migracion: responsable sin restriccion de chofer + persona de apoyo
-- Fecha: 2026-09-09
--
-- Dos cambios de regla de negocio:
--
--   1. El responsable de un REPARTO ya no tiene que ser chofer de flota propia.
--      age_crear_actividad y age_actualizar_actividad exigian
--      "trabajador chofer de flota propia (repartidor)", pero en la practica
--      reparte cualquier trabajador vigente. Esa validacion se relaja en los
--      archivos de funciones correspondientes (no aqui).
--
--   2. En la entrega suelen ir dos personas: el chofer y alguien de apoyo,
--      porque hay que subir los balones a un tercer o cuarto piso. Se anade
--      id_trabajador_apoyo junto al responsable.
--
-- age_asignar_responsable_actividad se reescribe porque no validaba nada: hacia
-- un UPDATE directo con lo que le llegara. Su peor efecto era que "Tomar
-- actividad" mandaba el trabajador del usuario y, si el usuario no tenia ficha
-- de trabajador, llegaba NULL y la actividad se quedaba SIN asignar mostrando
-- exito. Ahora se distingue explicitamente tomar de liberar.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_age_responsable_apoyo.sql
-- ============================================================

ALTER TABLE age_actividad
    ADD COLUMN IF NOT EXISTS id_trabajador_apoyo INT NULL REFERENCES tra_trabajadores(id);

CREATE INDEX IF NOT EXISTS idx_age_actividad_apoyo
    ON age_actividad (id_trabajador_apoyo)
    WHERE id_trabajador_apoyo IS NOT NULL;

-- ------------------------------------------------------------
-- age_asignar_responsable_actividad
--
-- p_liberar distingue las dos intenciones que antes se confundian:
--   FALSE (por defecto) -> se asigna; un responsable NULL es un error.
--   TRUE                -> se libera; se limpian responsable y apoyo.
-- ------------------------------------------------------------

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
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF COALESCE(p_liberar, FALSE) THEN
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
