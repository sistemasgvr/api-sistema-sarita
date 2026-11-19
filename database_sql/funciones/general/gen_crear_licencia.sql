-- Crea licencia
DROP FUNCTION IF EXISTS public.gen_crear_licencia (
  p_codigo character varying,
  p_id_chofer integer,
  p_fecha_emision date,
  p_fecha_vencimiento date,
  p_id_tipo_licencia integer,
  p_id_categoria_licencia integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_crear_licencia (
  p_codigo character varying,
  p_id_chofer integer,
  p_fecha_emision date,
  p_fecha_vencimiento date,
  p_id_tipo_licencia integer DEFAULT NULL::integer,
  p_id_categoria_licencia integer DEFAULT NULL::integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_licencia_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_licencia WHERE codigo = p_codigo) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una licencia con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_licencia WHERE codigo = p_codigo AND estado = 1)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_licencia (
        id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
        fecha_emision, fecha_vencimiento,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_licencia, p_id_categoria_licencia, p_id_chofer, p_codigo,
        p_fecha_emision, p_fecha_vencimiento,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_licencia(v_id);
END;
$function$;
