-- Corrige ven_listar_percepciones / com_listar_retenciones: jsonb_agg con ORDER BY
-- y LIMIT fuera del agregado (error 42803). Añade nombre de estado y de la contraparte.
BEGIN;
-- Function: ven_listar_percepciones
-- Listar percepciones con filtros

CREATE OR REPLACE FUNCTION ven_listar_percepciones(
    p_id_empresa integer DEFAULT NULL,
    p_fecha_desde date DEFAULT NULL,
    p_fecha_hasta date DEFAULT NULL,
    p_id_cliente integer DEFAULT NULL,
    p_estado character varying DEFAULT NULL,
    p_pagina integer DEFAULT 1,
    p_tamano integer DEFAULT 20
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total BIGINT;
    v_registros JSONB;
    v_offset INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_offset := (p_pagina - 1) * p_tamano;

    SELECT COUNT(*) INTO v_total
    FROM ven_percepcion p
    WHERE p.estado = 1
      AND (p_id_empresa IS NULL OR p.id_empresa = p_id_empresa)
      AND (p_fecha_desde IS NULL OR p.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR p.fecha_emision <= p_fecha_hasta)
      AND (p_id_cliente IS NULL OR p.id_cliente = p_id_cliente);

    -- jsonb_agg no admite ORDER BY/LIMIT fuera del agregado: se pagina en una
    -- subconsulta y se agrega sobre ella (con estado SUNAT y cliente legibles).
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'serie', p.serie,
            'numero', p.numero,
            'fecha_emision', p.fecha_emision,
            'id_empresa', p.id_empresa,
            'id_cliente', p.id_cliente,
            'regimen', p.regimen,
            'tasa', p.tasa,
            'base_imponible', p.base_imponible,
            'monto_percibido', p.monto_percibido,
            'monto_cobrado', p.monto_cobrado,
            'id_estado_sunat', p.id_estado_sunat,
            'ticket_sunat', p.ticket_sunat,
            'nombre_estado_sunat', p.nombre_estado_sunat,
            'nombre_cliente', p.nombre_cliente,
            'documento_cliente', p.documento_cliente
        )
        ORDER BY p.fecha_emision DESC, p.id DESC
    ), '[]'::jsonb) INTO v_registros
    FROM (
        SELECT x.*, es.nombre AS nombre_estado_sunat,
               COALESCE(NULLIF(TRIM(c.razon_social), ''),
                        NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')) AS nombre_cliente,
               c.numero_documento AS documento_cliente
        FROM ven_percepcion x
        LEFT JOIN gen_lista_opciones es ON es.id = x.id_estado_sunat
        LEFT JOIN cli_clientes c ON c.id = x.id_cliente
        WHERE x.estado = 1
      AND (p_id_empresa IS NULL OR x.id_empresa = p_id_empresa)
      AND (p_fecha_desde IS NULL OR x.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR x.fecha_emision <= p_fecha_hasta)
      AND (p_id_cliente IS NULL OR x.id_cliente = p_id_cliente)
        ORDER BY x.fecha_emision DESC, x.id DESC
        LIMIT p_tamano OFFSET v_offset
    ) p;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'pagina', p_pagina,
        'tamano', p_tamano
    );
END;
$function$;
-- Function: com_listar_retenciones
-- Listar retenciones con filtros

CREATE OR REPLACE FUNCTION com_listar_retenciones(
    p_id_empresa integer DEFAULT NULL,
    p_fecha_desde date DEFAULT NULL,
    p_fecha_hasta date DEFAULT NULL,
    p_id_proveedor integer DEFAULT NULL,
    p_estado character varying DEFAULT NULL,
    p_pagina integer DEFAULT 1,
    p_tamano integer DEFAULT 20
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_total BIGINT;
    v_registros JSONB;
    v_offset INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_offset := (p_pagina - 1) * p_tamano;

    SELECT COUNT(*) INTO v_total
    FROM com_retencion r
    WHERE r.estado = 1
      AND (p_id_empresa IS NULL OR r.id_empresa = p_id_empresa)
      AND (p_fecha_desde IS NULL OR r.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha_emision <= p_fecha_hasta)
      AND (p_id_proveedor IS NULL OR r.id_proveedor = p_id_proveedor);

    -- jsonb_agg no admite ORDER BY/LIMIT fuera del agregado: se pagina en una
    -- subconsulta y se agrega sobre ella (con estado SUNAT y proveedor legibles).
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', r.id,
            'serie', r.serie,
            'numero', r.numero,
            'fecha_emision', r.fecha_emision,
            'id_empresa', r.id_empresa,
            'id_proveedor', r.id_proveedor,
            'regimen', r.regimen,
            'tasa', r.tasa,
            'base_imponible', r.base_imponible,
            'monto_retenido', r.monto_retenido,
            'monto_pagado', r.monto_pagado,
            'id_estado_sunat', r.id_estado_sunat,
            'ticket_sunat', r.ticket_sunat,
            'nombre_estado_sunat', r.nombre_estado_sunat,
            'nombre_proveedor', r.nombre_proveedor,
            'documento_proveedor', r.documento_proveedor
        )
        ORDER BY r.fecha_emision DESC, r.id DESC
    ), '[]'::jsonb) INTO v_registros
    FROM (
        SELECT x.*, es.nombre AS nombre_estado_sunat,
               COALESCE(NULLIF(TRIM(c.razon_social), ''),
                        NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')) AS nombre_proveedor,
               c.numero_documento AS documento_proveedor
        FROM com_retencion x
        LEFT JOIN gen_lista_opciones es ON es.id = x.id_estado_sunat
        LEFT JOIN cli_clientes c ON c.id = x.id_proveedor
        WHERE x.estado = 1
      AND (p_id_empresa IS NULL OR x.id_empresa = p_id_empresa)
      AND (p_fecha_desde IS NULL OR x.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR x.fecha_emision <= p_fecha_hasta)
      AND (p_id_proveedor IS NULL OR x.id_proveedor = p_id_proveedor)
        ORDER BY x.fecha_emision DESC, x.id DESC
        LIMIT p_tamano OFFSET v_offset
    ) r;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'pagina', p_pagina,
        'tamano', p_tamano
    );
END;
$function$;
COMMIT;
