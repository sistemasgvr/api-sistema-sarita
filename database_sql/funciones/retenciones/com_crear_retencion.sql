-- Function: com_crear_retencion
-- Crear un comprobante de retención con su detalle

CREATE OR REPLACE FUNCTION com_crear_retencion(
    p_serie character varying,
    p_fecha_emision date,
    p_id_empresa integer,
    p_id_proveedor integer,
    p_id_sucursal integer,
    p_regimen character varying,
    p_tasa numeric,
    p_base_imponible numeric,
    p_monto_retenido numeric,
    p_monto_pagado numeric,
    p_observacion character varying,
    p_detalles jsonb,
    p_id_usuario_auditoria integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_retencion_id INTEGER;
    v_item JSONB;
    v_numero VARCHAR;
    v_siguiente BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_empresa IS NULL THEN
        RETURN json_build_object('error', 'La empresa emisora es obligatoria');
    END IF;

    IF p_id_proveedor IS NULL THEN
        RETURN json_build_object('error', 'El proveedor es obligatorio');
    END IF;

    IF p_regimen IS NULL OR TRIM(p_regimen) = '' THEN
        RETURN json_build_object('error', 'El régimen de retención es obligatorio');
    END IF;

    IF p_tasa IS NULL OR p_tasa <= 0 THEN
        RETURN json_build_object('error', 'La tasa de retención debe ser mayor a 0');
    END IF;

    -- Siguiente correlativo por empresa + serie: cada RUC numera aparte en
    -- SUNAT. Se cuentan también los anulados (no se reutilizan números).
    PERFORM pg_advisory_xact_lock(872017, hashtext(p_id_empresa::TEXT || '|' || UPPER(TRIM(p_serie))));

    SELECT COALESCE(MAX(numero::BIGINT), 0) INTO v_siguiente
    FROM com_retencion
    WHERE id_empresa = p_id_empresa
      AND UPPER(TRIM(serie)) = UPPER(TRIM(p_serie))
      AND numero ~ '^[0-9]+$';

    v_numero := LPAD((v_siguiente + 1)::TEXT, 8, '0');

    -- Insertar cabecera
    INSERT INTO com_retencion (
        serie, numero, fecha_emision, id_empresa, id_proveedor, id_sucursal,
        regimen, tasa, base_imponible, monto_retenido, monto_pagado,
        observacion, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        UPPER(TRIM(p_serie)), v_numero, p_fecha_emision, p_id_empresa, p_id_proveedor, p_id_sucursal,
        TRIM(p_regimen), p_tasa, p_base_imponible, p_monto_retenido, p_monto_pagado,
        p_observacion, p_id_usuario_auditoria, p_id_usuario_auditoria
    ) RETURNING id INTO v_retencion_id;

    -- Insertar detalle
    IF p_detalles IS NOT NULL AND jsonb_array_length(p_detalles) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
        LOOP
            INSERT INTO com_retencion_detalle (
                id_retencion, id_compra, tipo_doc, num_doc,
                fecha_emision, fecha_retencion, moneda,
                imp_total, imp_retenido, imp_pagar,
                tipo_cambio_moneda_ref, tipo_cambio_moneda_obj,
                tipo_cambio_factor, tipo_cambio_fecha
            ) VALUES (
                v_retencion_id,
                NULLIF((v_item->>'id_compra')::integer, 0),
                COALESCE(NULLIF(TRIM(v_item->>'tipo_doc'), ''), '01'),
                COALESCE(v_item->>'num_doc', ''),
                COALESCE((v_item->>'fecha_emision')::date, CURRENT_DATE),
                COALESCE((v_item->>'fecha_retencion')::date, CURRENT_DATE),
                COALESCE(NULLIF(TRIM(v_item->>'moneda'), ''), 'PEN'),
                COALESCE((v_item->>'imp_total')::numeric, 0),
                COALESCE((v_item->>'imp_retenido')::numeric, 0),
                COALESCE((v_item->>'imp_pagar')::numeric, 0),
                COALESCE(NULLIF(TRIM(v_item->>'tipo_cambio_moneda_ref'), ''), 'PEN'),
                COALESCE(NULLIF(TRIM(v_item->>'tipo_cambio_moneda_obj'), ''), 'PEN'),
                COALESCE((v_item->>'tipo_cambio_factor')::numeric, 1),
                (v_item->>'tipo_cambio_fecha')::date
            );
        END LOOP;
    END IF;

    RETURN json_build_object(
        'id', v_retencion_id,
        'serie', UPPER(TRIM(p_serie)),
        'numero', v_numero
    );
END;
$function$;
