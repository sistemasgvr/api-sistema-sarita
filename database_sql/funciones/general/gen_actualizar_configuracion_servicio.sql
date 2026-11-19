-- Actualiza configuracion servicio
DROP FUNCTION IF EXISTS public.gen_actualizar_configuracion_servicio (
  p_id integer,
  p_codigo character varying,
  p_nombre character varying,
  p_usuario character varying,
  p_contrasena character varying,
  p_email character varying,
  p_url character varying,
  p_observacion character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_actualizar_configuracion_servicio (
  p_id integer,
  p_codigo character varying DEFAULT NULL::character varying,
  p_nombre character varying DEFAULT NULL::character varying,
  p_usuario character varying DEFAULT NULL::character varying,
  p_contrasena character varying DEFAULT NULL::character varying,
  p_email character varying DEFAULT NULL::character varying,
  p_url character varying DEFAULT NULL::character varying,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_configuracion_servicio_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_configuracion_servicio WHERE codigo = p_codigo AND id <> p_id) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe un servicio con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_configuracion_servicio WHERE codigo = p_codigo AND estado = 1 AND id <> p_id)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    UPDATE gen_configuracion_servicio
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        usuario = COALESCE(p_usuario, usuario),
        contrasena = COALESCE(p_contrasena, contrasena),
        email = COALESCE(p_email, email),
        url = COALESCE(p_url, url),
        observacion = COALESCE(p_observacion, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_configuracion_servicio(p_id);
END;
$function$;
