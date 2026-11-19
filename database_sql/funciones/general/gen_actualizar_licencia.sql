-- Actualiza licencia
DROP FUNCTION IF EXISTS public.gen_actualizar_licencia (
  p_id integer,
  p_id_chofer integer,
  p_codigo character varying,
  p_id_tipo_licencia integer,
  p_id_categoria_licencia integer,
  p_fecha_emision date,
  p_fecha_vencimiento date,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_actualizar_licencia (
  p_id integer,
  p_id_chofer integer DEFAULT NULL::integer,
  p_codigo character varying DEFAULT NULL::character varying,
  p_id_tipo_licencia integer DEFAULT NULL::integer,
  p_id_categoria_licencia integer DEFAULT NULL::integer,
  p_fecha_emision date DEFAULT NULL::date,
  p_fecha_vencimiento date DEFAULT NULL::date,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_licencia_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_licencia WHERE codigo = p_codigo AND id <> p_id) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una licencia con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_licencia WHERE codigo = p_codigo AND estado = 1 AND id <> p_id)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    UPDATE gen_licencia
    SET
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        codigo = COALESCE(p_codigo, codigo),
        id_tipo_licencia = COALESCE(p_id_tipo_licencia, id_tipo_licencia),
        id_categoria_licencia = COALESCE(p_id_categoria_licencia, id_categoria_licencia),
        fecha_emision = COALESCE(p_fecha_emision, fecha_emision),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_licencia(p_id);
END;
$function$;
