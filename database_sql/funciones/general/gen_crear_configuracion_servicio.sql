-- Crea configuracion servicio
DROP FUNCTION IF EXISTS public.gen_crear_configuracion_servicio (
  p_codigo character varying,
  p_nombre character varying,
  p_usuario character varying,
  p_contrasena character varying,
  p_email character varying,
  p_url character varying,
  p_observacion character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_crear_configuracion_servicio (
  p_codigo character varying,
  p_nombre character varying,
  p_usuario character varying DEFAULT NULL::character varying,
  p_contrasena character varying DEFAULT NULL::character varying,
  p_email character varying DEFAULT NULL::character varying,
  p_url character varying DEFAULT NULL::character varying,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_configuracion_servicio_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_configuracion_servicio WHERE codigo = p_codigo) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe un servicio con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_configuracion_servicio WHERE codigo = p_codigo AND estado = 1)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_configuracion_servicio (
        codigo,
        nombre,
        usuario,
        contrasena,
        email,
        url,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_usuario,
        p_contrasena,
        p_email,
        p_url,
        p_observacion,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_configuracion_servicio(v_id);
END;
$function$;
