-- Crea una actividad de recojo de balones para un préstamo
DROP FUNCTION IF EXISTS public.age_crear_recojo_prestamo (
  p_id_prestamo integer,
  p_fecha_programada date,
  p_hora_inicio_estimada time without time zone,
  p_id_trabajador_responsable integer,
  p_observaciones character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.age_crear_recojo_prestamo (
  p_id_prestamo integer,
  p_fecha_programada date DEFAULT NULL::date,
  p_hora_inicio_estimada time without time zone DEFAULT NULL::time without time zone,
  p_id_trabajador_responsable integer DEFAULT NULL::integer,
  p_observaciones character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
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
