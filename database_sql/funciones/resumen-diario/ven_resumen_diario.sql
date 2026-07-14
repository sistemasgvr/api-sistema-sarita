-- ============================================================
-- Resumen diario de boletas (historial + detalle)
-- Aplicar en BD existente y dejar reflejado en database.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS ven_resumen_diario (
    id                      SERIAL PRIMARY KEY,
    fecha                   DATE NOT NULL,
    correlativo             VARCHAR(10) NOT NULL,
    identificador           VARCHAR(50),
    ticket_sunat            VARCHAR(100),
    id_estado_sunat         INT REFERENCES gen_lista_opciones(id),
    hash_documento          VARCHAR(100),
    xml_firmado             TEXT,
    cdr_respuesta           TEXT,
    moneda                  VARCHAR(3) DEFAULT 'PEN',
    cantidad_docs           INT NOT NULL DEFAULT 0,
    total_importe           NUMERIC(12,4) NOT NULL DEFAULT 0,
    total_igv               NUMERIC(12,4) NOT NULL DEFAULT 0,
    total_valor_venta       NUMERIC(12,4) NOT NULL DEFAULT 0,
    observacion             VARCHAR(500),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW(),
    UNIQUE (fecha, correlativo)
);

CREATE TABLE IF NOT EXISTS ven_resumen_diario_detalle (
    id                      SERIAL PRIMARY KEY,
    id_resumen              INT NOT NULL REFERENCES ven_resumen_diario(id),
    id_comprobante          INT NOT NULL REFERENCES ven_comprobante(id),
    item                    INT NOT NULL,
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_resumen, id_comprobante)
);

CREATE INDEX IF NOT EXISTS idx_ven_resumen_diario_fecha ON ven_resumen_diario(fecha);
CREATE INDEX IF NOT EXISTS idx_ven_resumen_diario_ticket ON ven_resumen_diario(ticket_sunat);
CREATE INDEX IF NOT EXISTS idx_ven_resumen_diario_estado_sunat ON ven_resumen_diario(id_estado_sunat);
CREATE INDEX IF NOT EXISTS idx_ven_resumen_detalle_resumen ON ven_resumen_diario_detalle(id_resumen);
CREATE INDEX IF NOT EXISTS idx_ven_resumen_detalle_comprobante ON ven_resumen_diario_detalle(id_comprobante);

CREATE OR REPLACE FUNCTION ven_obtener_siguiente_correlativo_resumen(
    p_fecha DATE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_ultimo INTEGER;
    v_siguiente VARCHAR(10);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(MAX(NULLIF(regexp_replace(correlativo, '\D', '', 'g'), '')::INTEGER), 0)
    INTO v_ultimo
    FROM ven_resumen_diario
    WHERE estado = 1
      AND fecha = p_fecha;

    v_siguiente := LPAD((v_ultimo + 1)::TEXT, 3, '0');

    RETURN json_build_object(
        'fecha', p_fecha,
        'ultimo_correlativo', CASE WHEN v_ultimo = 0 THEN NULL ELSE LPAD(v_ultimo::TEXT, 3, '0') END,
        'correlativo', v_siguiente
    );
END;
$function$;

CREATE OR REPLACE FUNCTION ven_obtener_resumen_diario(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            r.id,
            r.fecha,
            r.correlativo,
            r.identificador,
            r.ticket_sunat,
            r.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            r.hash_documento,
            r.cdr_respuesta,
            r.moneda,
            r.cantidad_docs,
            r.total_importe,
            r.total_igv,
            r.total_valor_venta,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            r.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM ven_resumen_diario r
        LEFT JOIN gen_lista_opciones es ON r.id_estado_sunat = es.id
        LEFT JOIN auth_usuarios uc ON r.id_usuario_creacion = uc.id
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL, 'detalles', '[]'::JSON);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON) INTO v_detalles
    FROM (
        SELECT
            d.id,
            d.id_resumen,
            d.id_comprobante,
            d.item,
            c.serie,
            c.numero,
            tc.descripcion AS codigo_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            c.fecha AS fecha_comprobante,
            c.total_importe,
            c.igv,
            c.valor_venta,
            es.nombre AS nombre_estado_sunat,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente
        FROM ven_resumen_diario_detalle d
        INNER JOIN ven_comprobante c ON d.id_comprobante = c.id
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        WHERE d.id_resumen = p_id AND d.estado = 1
    ) d;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles
    );
END;
$function$;

CREATE OR REPLACE FUNCTION ven_listar_resumen_diario(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_estado_sunat INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM ven_resumen_diario r
    WHERE r.estado = 1
      AND (p_id_estado_sunat IS NULL OR r.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR r.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(r.identificador, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(r.ticket_sunat, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(r.correlativo, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            r.id,
            r.fecha,
            r.correlativo,
            r.identificador,
            r.ticket_sunat,
            r.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            r.moneda,
            r.cantidad_docs,
            r.total_importe,
            r.total_igv,
            r.total_valor_venta,
            r.fecha_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM ven_resumen_diario r
        LEFT JOIN gen_lista_opciones es ON r.id_estado_sunat = es.id
        LEFT JOIN auth_usuarios uc ON r.id_usuario_creacion = uc.id
        WHERE r.estado = 1
          AND (p_id_estado_sunat IS NULL OR r.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR r.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(r.identificador, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(r.ticket_sunat, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(r.correlativo, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY r.fecha DESC, r.correlativo DESC, r.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

CREATE OR REPLACE FUNCTION ven_crear_resumen_diario(
    p_fecha DATE,
    p_correlativo VARCHAR,
    p_ticket_sunat VARCHAR DEFAULT NULL,
    p_id_estado_sunat INTEGER DEFAULT NULL,
    p_cdr_respuesta TEXT DEFAULT NULL,
    p_moneda VARCHAR DEFAULT 'PEN',
    p_cantidad_docs INTEGER DEFAULT 0,
    p_total_importe NUMERIC DEFAULT 0,
    p_total_igv NUMERIC DEFAULT 0,
    p_total_valor_venta NUMERIC DEFAULT 0,
    p_ids_comprobante JSON DEFAULT '[]'::JSON,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_correlativo VARCHAR(10);
    v_identificador VARCHAR(50);
    v_ids INTEGER[];
    v_item INTEGER := 0;
    v_id_comp INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del resumen es obligatoria', 'registro', NULL);
    END IF;

    v_correlativo := LPAD(regexp_replace(COALESCE(NULLIF(TRIM(p_correlativo), ''), '001'), '\D', '', 'g'), 3, '0');
    v_identificador := 'RC-' || to_char(p_fecha, 'YYYYMMDD') || '-' || v_correlativo;

    IF EXISTS (
        SELECT 1 FROM ven_resumen_diario
        WHERE estado = 1 AND fecha = p_fecha AND correlativo = v_correlativo
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe un resumen con correlativo ' || v_correlativo || ' para esa fecha',
            'registro',
            NULL
        );
    END IF;

    SELECT COALESCE(array_agg((value::TEXT)::INTEGER), ARRAY[]::INTEGER[])
    INTO v_ids
    FROM json_array_elements_text(COALESCE(p_ids_comprobante, '[]'::JSON));

    IF COALESCE(array_length(v_ids, 1), 0) = 0 THEN
        RETURN json_build_object('error', 'El resumen debe incluir al menos un comprobante', 'registro', NULL);
    END IF;

    INSERT INTO ven_resumen_diario (
        fecha,
        correlativo,
        identificador,
        ticket_sunat,
        id_estado_sunat,
        cdr_respuesta,
        moneda,
        cantidad_docs,
        total_importe,
        total_igv,
        total_valor_venta,
        id_usuario_creacion,
        id_usuario_modificacion
    ) VALUES (
        p_fecha,
        v_correlativo,
        v_identificador,
        NULLIF(TRIM(p_ticket_sunat), ''),
        p_id_estado_sunat,
        p_cdr_respuesta,
        COALESCE(NULLIF(TRIM(p_moneda), ''), 'PEN'),
        COALESCE(p_cantidad_docs, array_length(v_ids, 1)),
        COALESCE(p_total_importe, 0),
        COALESCE(p_total_igv, 0),
        COALESCE(p_total_valor_venta, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOREACH v_id_comp IN ARRAY v_ids LOOP
        v_item := v_item + 1;
        INSERT INTO ven_resumen_diario_detalle (
            id_resumen,
            id_comprobante,
            item,
            id_usuario_creacion,
            id_usuario_modificacion
        ) VALUES (
            v_id,
            v_id_comp,
            v_item,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    RETURN ven_obtener_resumen_diario(v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION ven_registrar_respuesta_resumen_diario(
    p_id INTEGER,
    p_id_estado_sunat INTEGER DEFAULT NULL,
    p_ticket_sunat VARCHAR DEFAULT NULL,
    p_cdr_respuesta TEXT DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM ven_resumen_diario WHERE id = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_estado_sunat IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_estado_sunat AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El estado SUNAT indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    UPDATE ven_resumen_diario
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN ven_obtener_resumen_diario(p_id);
END;
$function$;
