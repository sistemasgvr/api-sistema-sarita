-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_actualizar_cuenta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS fin_actualizar_cuenta(p_id integer, p_tipo character varying, p_id_tercero integer, p_tercero_nombre character varying, p_fecha_emision date, p_fecha_vencimiento date, p_monto numeric, p_descripcion character varying, p_observacion character varying, p_numero_comprobante character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_actualizar_cuenta(p_id integer, p_tipo character varying DEFAULT NULL::character varying, p_id_tercero integer DEFAULT NULL::integer, p_tercero_nombre character varying DEFAULT NULL::character varying, p_fecha_emision date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_monto numeric DEFAULT NULL::numeric, p_descripcion character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_numero_comprobante character varying DEFAULT NULL::character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_cuenta        fin_cuenta%ROWTYPE;
    v_id_tipo       INT;
    v_tiene_pagos   BOOLEAN;
    v_es_plan       BOOLEAN;
    v_nuevo_tercero INT;
    v_registro      JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La cuenta no existe o está inactiva');
    END IF;

    -- No permitir editar cuotas hijas directamente
    IF v_cuenta.id_cuenta_padre IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'No se puede editar una cuota individual; edita la cuenta padre del plan');
    END IF;

    -- Validación opcional del tipo
    IF p_tipo IS NOT NULL THEN
        SELECT glo.id INTO v_id_tipo
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = UPPER(p_tipo)
        LIMIT 1;
        IF v_id_tipo IS NOT NULL AND v_cuenta.id_tipo_cuenta <> v_id_tipo THEN
            RETURN json_build_object('registro', NULL, 'error', 'La cuenta no corresponde al tipo indicado');
        END IF;
    END IF;

    v_es_plan := (v_cuenta.numero_cuotas_total IS NOT NULL);

    SELECT EXISTS(
        SELECT 1 FROM fin_pago WHERE id_cuenta = p_id AND estado = 1
    ) INTO v_tiene_pagos;

    -- Si hay pagos y quieren cambiar campos "financieros" (tercero/monto/fecha_emision), rechazar
    IF v_tiene_pagos AND (
        p_id_tercero IS NOT NULL
        OR (p_tercero_nombre IS NOT NULL AND p_tercero_nombre <> '')
        OR p_fecha_emision IS NOT NULL
        OR p_monto IS NOT NULL
    ) THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta cuenta ya tiene pagos: solo puedes editar descripción, observación, comprobante y fecha de vencimiento');
    END IF;

    IF v_es_plan AND (
        p_id_tercero IS NOT NULL
        OR (p_tercero_nombre IS NOT NULL AND p_tercero_nombre <> '')
        OR p_fecha_emision IS NOT NULL
        OR p_monto IS NOT NULL
        OR p_fecha_vencimiento IS NOT NULL
    ) THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta cuenta es un plan de cuotas: solo puedes editar descripción, observación y comprobante');
    END IF;

    -- Validaciones de valores
    IF p_id_tercero IS NOT NULL THEN
        SELECT id INTO v_nuevo_tercero FROM cli_clientes WHERE id = p_id_tercero AND estado = 1;
        IF v_nuevo_tercero IS NULL THEN
            RETURN json_build_object('registro', NULL, 'error', 'El tercero no existe o está inactivo');
        END IF;
    END IF;

    IF p_monto IS NOT NULL AND p_monto <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto debe ser mayor a cero');
    END IF;

    IF p_fecha_vencimiento IS NOT NULL
       AND COALESCE(p_fecha_emision, v_cuenta.fecha_emision) IS NOT NULL
       AND p_fecha_vencimiento < COALESCE(p_fecha_emision, v_cuenta.fecha_emision) THEN
        RETURN json_build_object('registro', NULL, 'error',
            'La fecha de vencimiento no puede ser anterior a la emisión');
    END IF;

    -- Actualización dinámica: solo cambia lo que llega no-null
    UPDATE fin_cuenta SET
        id_tercero          = COALESCE(p_id_tercero, id_tercero),
        tercero_nombre      = CASE
            WHEN p_tercero_nombre IS NULL THEN tercero_nombre
            WHEN TRIM(p_tercero_nombre) = '' THEN NULL
            ELSE TRIM(p_tercero_nombre)
        END,
        fecha_emision       = COALESCE(p_fecha_emision, fecha_emision),
        fecha_vencimiento   = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        monto_pendiente     = COALESCE(p_monto, monto_pendiente),
        monto_saldo         = CASE
            WHEN p_monto IS NOT NULL THEN p_monto - COALESCE(monto_abonado, 0)
            ELSE monto_saldo
        END,
        descripcion         = CASE
            WHEN p_descripcion IS NULL THEN descripcion
            WHEN TRIM(p_descripcion) = '' THEN NULL
            ELSE TRIM(p_descripcion)
        END,
        observacion         = CASE
            WHEN p_observacion IS NULL THEN observacion
            WHEN TRIM(p_observacion) = '' THEN NULL
            ELSE TRIM(p_observacion)
        END,
        numero_comprobante  = CASE
            WHEN p_numero_comprobante IS NULL THEN numero_comprobante
            WHEN TRIM(p_numero_comprobante) = '' THEN NULL
            ELSE TRIM(p_numero_comprobante)
        END,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion  = NOW()
    WHERE id = p_id;

    -- Validar que quede tercero (uno de los dos)
    SELECT * INTO v_cuenta FROM fin_cuenta WHERE id = p_id;
    IF v_cuenta.id_tercero IS NULL AND (v_cuenta.tercero_nombre IS NULL OR TRIM(v_cuenta.tercero_nombre) = '') THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Debe quedar al menos un tercero (id o nombre libre)');
    END IF;

    -- Devolver el registro actualizado
    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            fc.id, fc.id_tipo_cuenta, tcu.nombre AS tipo,
            fc.id_tercero, fc.tercero_nombre,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            fc.descripcion, fc.numero_comprobante,
            fc.fecha_emision, fc.fecha_vencimiento,
            fc.monto_pendiente, fc.monto_abonado, fc.monto_saldo AS saldo,
            fc.observacion
        FROM fin_cuenta fc
        JOIN gen_lista_opciones tcu ON tcu.id = fc.id_tipo_cuenta
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
