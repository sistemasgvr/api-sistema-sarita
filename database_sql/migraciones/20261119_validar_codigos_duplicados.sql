-- Validación previa de códigos duplicados en catálogos de Configuración.
--  * Problema (reporte del 18/11): crear una condición de pago con un código que ya existía
--    (p. ej. CRED21) fallaba con 23505 en la UNIQUE y el usuario veía «Error interno del servidor».
--    Lo mismo pasaba en sucursales, servicios, licencias y empresas (RUC).
--  * Ahora: las funciones crear/actualizar validan antes del INSERT/UPDATE y devuelven
--    {error: 'Ya existe … con el código X. Usa otro.'}, que la API responde como 400 legible.
--    Si el código pertenece a un registro dado de baja, el mensaje lo dice (la UNIQUE lo cuenta).
--  * Complemento en la API: common/filters/pg-error.helper.ts traduce cualquier 23505 que se escape.
-- Idempotente (DROP/CREATE OR REPLACE). Respaldar la base antes de publicar.
BEGIN;

-- Crea condicion pago
DROP FUNCTION IF EXISTS public.gen_crear_condicion_pago (
  p_codigo character varying,
  p_nombre character varying,
  p_dias_credito integer,
  p_numero_cuotas integer,
  p_dia_mes_pago integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_crear_condicion_pago (
  p_codigo character varying,
  p_nombre character varying,
  p_dias_credito integer DEFAULT 0,
  p_numero_cuotas integer DEFAULT NULL::integer,
  p_dia_mes_pago integer DEFAULT NULL::integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
    v_dias INTEGER;
    v_cuotas INTEGER;
    v_dia INTEGER;
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_condicion_pago_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_condicion_pago WHERE codigo = p_codigo) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una condición de pago con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_condicion_pago WHERE codigo = p_codigo AND estado = 1)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    v_dias := COALESCE(p_dias_credito, 0);
    v_cuotas := NULLIF(p_numero_cuotas, 0);
    v_dia := p_dia_mes_pago;

    IF v_dias < 0 THEN
        RETURN json_build_object('error', 'Los días de crédito no pueden ser negativos', 'registro', NULL);
    END IF;

    IF v_cuotas IS NOT NULL AND v_cuotas < 1 THEN
        RETURN json_build_object('error', 'El número de cuotas debe ser al menos 1', 'registro', NULL);
    END IF;

    IF COALESCE(v_cuotas, 0) > 1 THEN
        IF v_dia IS NULL OR v_dia < 1 OR v_dia > 31 THEN
            RETURN json_build_object(
                'error',
                'En plan de cuotas debes indicar el día del mes a cobrar (1 a 31)',
                'registro',
                NULL
            );
        END IF;
    ELSE
        v_dia := NULL;
        IF COALESCE(v_cuotas, 0) <= 1 THEN
            v_cuotas := NULL;
        END IF;
    END IF;

    INSERT INTO gen_condicion_pago (
        codigo,
        nombre,
        dias_credito,
        numero_cuotas,
        dia_mes_pago,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        v_dias,
        v_cuotas,
        v_dia,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_condicion_pago(v_id);
END;
$function$;

-- Actualiza condicion pago
DROP FUNCTION IF EXISTS public.gen_actualizar_condicion_pago (
  p_id integer,
  p_codigo character varying,
  p_nombre character varying,
  p_dias_credito integer,
  p_numero_cuotas integer,
  p_dia_mes_pago integer,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_actualizar_condicion_pago (
  p_id integer,
  p_codigo character varying DEFAULT NULL::character varying,
  p_nombre character varying DEFAULT NULL::character varying,
  p_dias_credito integer DEFAULT NULL::integer,
  p_numero_cuotas integer DEFAULT NULL::integer,
  p_dia_mes_pago integer DEFAULT NULL::integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_dias INTEGER;
    v_cuotas INTEGER;
    v_dia INTEGER;
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_condicion_pago_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_condicion_pago WHERE codigo = p_codigo AND id <> p_id) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una condición de pago con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_condicion_pago WHERE codigo = p_codigo AND estado = 1 AND id <> p_id)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT
        COALESCE(p_dias_credito, dias_credito),
        NULLIF(COALESCE(p_numero_cuotas, numero_cuotas), 0),
        COALESCE(p_dia_mes_pago, dia_mes_pago)
    INTO v_dias, v_cuotas, v_dia
    FROM gen_condicion_pago
    WHERE id = p_id;

    IF p_dias_credito IS NOT NULL THEN
        v_dias := p_dias_credito;
        v_cuotas := NULLIF(p_numero_cuotas, 0);
        v_dia := p_dia_mes_pago;
    END IF;

    IF v_dias < 0 THEN
        RETURN json_build_object('error', 'Los días de crédito no pueden ser negativos', 'registro', NULL);
    END IF;

    IF COALESCE(v_cuotas, 0) > 1 THEN
        IF v_dia IS NULL OR v_dia < 1 OR v_dia > 31 THEN
            RETURN json_build_object(
                'error',
                'En plan de cuotas debes indicar el día del mes a cobrar (1 a 31)',
                'registro',
                NULL
            );
        END IF;
    ELSE
        v_cuotas := NULL;
        v_dia := NULL;
    END IF;

    UPDATE gen_condicion_pago
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        dias_credito = v_dias,
        numero_cuotas = v_cuotas,
        dia_mes_pago = v_dia,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN gen_obtener_condicion_pago(p_id);
END;
$function$;

-- Crea sucursal
DROP FUNCTION IF EXISTS public.gen_crear_sucursal (
  p_codigo character varying,
  p_nombre character varying,
  p_direccion character varying,
  p_id_departamento integer,
  p_id_provincia integer,
  p_id_distrito integer,
  p_telefono character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_crear_sucursal (
  p_codigo character varying,
  p_nombre character varying,
  p_direccion character varying DEFAULT NULL::character varying,
  p_id_departamento integer DEFAULT NULL::integer,
  p_id_provincia integer DEFAULT NULL::integer,
  p_id_distrito integer DEFAULT NULL::integer,
  p_telefono character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_sucursal_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_sucursal WHERE codigo = p_codigo) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una sucursal con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_sucursal WHERE codigo = p_codigo AND estado = 1)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_sucursal (
        codigo,
        nombre,
        direccion,
        id_departamento,
        id_provincia,
        id_distrito,
        telefono,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_direccion,
        p_id_departamento,
        p_id_provincia,
        p_id_distrito,
        p_telefono,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_sucursal(v_id);
END;
$function$;

-- Actualiza sucursal
DROP FUNCTION IF EXISTS public.gen_actualizar_sucursal (
  p_id integer,
  p_codigo character varying,
  p_nombre character varying,
  p_direccion character varying,
  p_id_departamento integer,
  p_id_provincia integer,
  p_id_distrito integer,
  p_telefono character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_actualizar_sucursal (
  p_id integer,
  p_codigo character varying DEFAULT NULL::character varying,
  p_nombre character varying DEFAULT NULL::character varying,
  p_direccion character varying DEFAULT NULL::character varying,
  p_id_departamento integer DEFAULT NULL::integer,
  p_id_provincia integer DEFAULT NULL::integer,
  p_id_distrito integer DEFAULT NULL::integer,
  p_telefono character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_sucursal_codigo_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_codigo IS NOT NULL AND EXISTS (SELECT 1 FROM gen_sucursal WHERE codigo = p_codigo AND id <> p_id) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una sucursal con el código %s%s. Usa otro.',
                p_codigo,
                CASE WHEN EXISTS (SELECT 1 FROM gen_sucursal WHERE codigo = p_codigo AND estado = 1 AND id <> p_id)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    UPDATE gen_sucursal
    SET
        codigo = COALESCE(p_codigo, codigo),
        nombre = COALESCE(p_nombre, nombre),
        direccion = COALESCE(p_direccion, direccion),
        id_departamento = COALESCE(p_id_departamento, id_departamento),
        id_provincia = COALESCE(p_id_provincia, id_provincia),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        telefono = COALESCE(p_telefono, telefono),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_sucursal(p_id);
END;
$function$;

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

-- Actualiza empresa
DROP FUNCTION IF EXISTS public.gen_actualizar_empresa (
  p_id integer,
  p_ruc character varying,
  p_razon_social character varying,
  p_nombre_comercial character varying,
  p_direccion character varying,
  p_telefono character varying,
  p_email character varying,
  p_tolerancia_m3_ruta_pueblo numeric,
  p_psi_minimo_util numeric,
  p_id_usuario_auditoria integer,
  p_id_distrito integer
);

CREATE OR REPLACE FUNCTION public.gen_actualizar_empresa (
  p_id integer,
  p_ruc character varying DEFAULT NULL::character varying,
  p_razon_social character varying DEFAULT NULL::character varying,
  p_nombre_comercial character varying DEFAULT NULL::character varying,
  p_direccion character varying DEFAULT NULL::character varying,
  p_telefono character varying DEFAULT NULL::character varying,
  p_email character varying DEFAULT NULL::character varying,
  p_tolerancia_m3_ruta_pueblo numeric DEFAULT NULL::numeric,
  p_psi_minimo_util numeric DEFAULT NULL::numeric,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_id_distrito integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    -- Validación previa de duplicado: la UNIQUE gen_empresa_ruc_key también cuenta los
    -- registros dados de baja. Sin esto el INSERT/UPDATE falla con 23505 y el
    -- usuario ve un error genérico (reporte del 18/11, condición de pago CRED21).
    IF p_ruc IS NOT NULL AND EXISTS (SELECT 1 FROM gen_empresa WHERE ruc = p_ruc AND id <> p_id) THEN
        RETURN json_build_object(
            'error',
            format(
                'Ya existe una empresa con el RUC %s%s. Usa otro.',
                p_ruc,
                CASE WHEN EXISTS (SELECT 1 FROM gen_empresa WHERE ruc = p_ruc AND estado = 1 AND id <> p_id)
                     THEN '' ELSE ' (el registro existente está dado de baja)' END
            ),
            'registro', NULL
        );
    END IF;

    SET TIME ZONE 'America/Lima';

    IF p_tolerancia_m3_ruta_pueblo IS NOT NULL AND p_tolerancia_m3_ruta_pueblo < 0 THEN
        RETURN json_build_object('error', 'La tolerancia de ruta pueblos no puede ser negativa', 'registro', NULL);
    END IF;

    IF p_psi_minimo_util IS NOT NULL AND p_psi_minimo_util < 0 THEN
        RETURN json_build_object('error', 'El umbral PSI mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_distrito IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_distrito WHERE id = p_id_distrito AND estado = 1 AND codigo_ubigeo IS NOT NULL
    ) THEN
        RETURN json_build_object('error', 'El distrito fiscal no existe o no tiene código ubigeo', 'registro', NULL);
    END IF;

    UPDATE gen_empresa
    SET
        ruc = COALESCE(p_ruc, ruc),
        razon_social = COALESCE(p_razon_social, razon_social),
        nombre_comercial = COALESCE(p_nombre_comercial, nombre_comercial),
        direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        email = COALESCE(p_email, email),
        tolerancia_m3_ruta_pueblo = COALESCE(p_tolerancia_m3_ruta_pueblo, tolerancia_m3_ruta_pueblo),
        psi_minimo_util = COALESCE(p_psi_minimo_util, psi_minimo_util),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_empresa(p_id);
END;
$function$;

COMMIT;
