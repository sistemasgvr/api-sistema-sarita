-- Function: age_crear_recojo_prestamo
-- Synced from migracion 20260909_age_crear_recojo_hora_inicio.sql

DROP FUNCTION IF EXISTS age_crear_recojo_prestamo(integer, date, integer, character varying, integer);
DROP FUNCTION IF EXISTS age_crear_recojo_prestamo(integer, date, time without time zone, integer, character varying, integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_prestamo(
    p_id_prestamo integer,
    p_fecha_programada date DEFAULT NULL::date,
    p_hora_inicio_estimada time without time zone DEFAULT NULL::time without time zone,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN age_crear_recojo_origen(
        'PRESTAMO',
        p_id_prestamo,
        p_fecha_programada,
        p_hora_inicio_estimada,
        p_id_trabajador_responsable,
        p_observaciones,
        p_id_usuario_auditoria
    );
END;
$function$;
