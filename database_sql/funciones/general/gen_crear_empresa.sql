-- Crea empresa
DROP FUNCTION IF EXISTS public.gen_crear_empresa (
  p_ruc character varying,
  p_razon_social character varying,
  p_nombre_comercial character varying,
  p_direccion character varying,
  p_telefono character varying,
  p_email character varying,
  p_id_usuario_auditoria integer,
  p_tolerancia_m3_ruta_pueblo numeric,
  p_psi_minimo_util numeric,
  p_id_distrito integer
);

CREATE OR REPLACE FUNCTION public.gen_crear_empresa (
  p_ruc character varying,
  p_razon_social character varying DEFAULT NULL::character varying,
  p_nombre_comercial character varying DEFAULT NULL::character varying,
  p_direccion character varying DEFAULT NULL::character varying,
  p_telefono character varying DEFAULT NULL::character varying,
  p_email character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_tolerancia_m3_ruta_pueblo numeric DEFAULT NULL::numeric,
  p_psi_minimo_util numeric DEFAULT NULL::numeric,
  p_id_distrito integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_empresa_ruc_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_ruc IS NOT NULL AND EXISTS (SELECT 1 FROM gen_empresa WHERE ruc = p_ruc) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una empresa con el RUC %s%s. Usa otro.',
                p_ruc,
                CASE WHEN EXISTS (SELECT 1 FROM gen_empresa WHERE ruc = p_ruc AND estado = 1)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_empresa (
        ruc,
        razon_social,
        nombre_comercial,
        direccion,
        telefono,
        email,
        tolerancia_m3_ruta_pueblo,
        psi_minimo_util,
        id_distrito,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_ruc,
        p_razon_social,
        p_nombre_comercial,
        p_direccion,
        p_telefono,
        p_email,
        p_tolerancia_m3_ruta_pueblo,
        p_psi_minimo_util,
        p_id_distrito,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_empresa(v_id);
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;
