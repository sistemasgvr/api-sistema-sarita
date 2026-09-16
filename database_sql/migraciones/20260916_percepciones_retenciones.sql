-- Módulos de percepción (ven_percepcion) y retención (com_retencion): tablas,
-- funciones, catálogos SUNAT 22/23 y permisos. Ensambla tablas/, funciones/ y
-- seeds/ del repo; idempotente en catálogos y permisos. Si ya se aplicó una
-- versión anterior, basta con 20260916_percepciones_retenciones_fix_listado.sql.
BEGIN;

-- >>> tablas/ventas/ven_percepcion.sql
CREATE TABLE IF NOT EXISTS ven_percepcion (
    id integer NOT NULL,
    serie character varying(10) NOT NULL,
    numero character varying(15) NOT NULL,
    fecha_emision date NOT NULL,
    id_empresa integer NOT NULL,
    id_cliente integer NOT NULL,
    id_sucursal integer,
    regimen character varying(5) NOT NULL,
    tasa numeric(8,4) NOT NULL,
    base_imponible numeric(12,4) DEFAULT 0 NOT NULL,
    monto_percibido numeric(12,4) DEFAULT 0 NOT NULL,
    monto_cobrado numeric(12,4) DEFAULT 0 NOT NULL,
    observacion character varying(500),
    id_estado_sunat integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS ven_percepcion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_percepcion_id_seq OWNED BY public.ven_percepcion.id;

ALTER TABLE ven_percepcion ALTER COLUMN id SET DEFAULT nextval('public.ven_percepcion_id_seq'::regclass);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_pkey PRIMARY KEY (id);

-- Correlativo único por empresa + serie (cada RUC numera aparte en SUNAT).
ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_empresa_serie_numero_key UNIQUE (id_empresa, serie, numero);

CREATE INDEX idx_ven_percepcion_empresa ON ven_percepcion USING btree (id_empresa);

CREATE INDEX idx_ven_percepcion_cliente ON ven_percepcion USING btree (id_cliente);

CREATE INDEX idx_ven_percepcion_fecha ON ven_percepcion USING btree (fecha_emision);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);


ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_percepcion ADD CONSTRAINT ven_percepcion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);


-- >>> tablas/ventas/ven_percepcion_detalle.sql
CREATE TABLE IF NOT EXISTS ven_percepcion_detalle (
    id integer NOT NULL,
    id_percepcion integer NOT NULL,
    id_comprobante integer,
    tipo_doc character varying(5) NOT NULL,
    num_doc character varying(30) NOT NULL,
    fecha_emision date NOT NULL,
    fecha_percepcion date NOT NULL,
    moneda character varying(5) DEFAULT 'PEN' NOT NULL,
    imp_total numeric(12,4) DEFAULT 0 NOT NULL,
    imp_percibido numeric(12,4) DEFAULT 0 NOT NULL,
    imp_cobrar numeric(12,4) DEFAULT 0 NOT NULL,
    tipo_cambio_moneda_ref character varying(5) DEFAULT 'PEN',
    tipo_cambio_moneda_obj character varying(5) DEFAULT 'PEN',
    tipo_cambio_factor numeric(10,6) DEFAULT 1,
    tipo_cambio_fecha date,
    estado integer DEFAULT 1 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS ven_percepcion_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_percepcion_detalle_id_seq OWNED BY public.ven_percepcion_detalle.id;

ALTER TABLE ven_percepcion_detalle ALTER COLUMN id SET DEFAULT nextval('public.ven_percepcion_detalle_id_seq'::regclass);

ALTER TABLE ven_percepcion_detalle ADD CONSTRAINT ven_percepcion_detalle_pkey PRIMARY KEY (id);

ALTER TABLE ven_percepcion_detalle ADD CONSTRAINT ven_percepcion_detalle_id_percepcion_fkey FOREIGN KEY (id_percepcion) REFERENCES public.ven_percepcion(id);

ALTER TABLE ven_percepcion_detalle ADD CONSTRAINT ven_percepcion_detalle_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);


-- >>> tablas/compras/com_retencion.sql
CREATE TABLE IF NOT EXISTS com_retencion (
    id integer NOT NULL,
    serie character varying(10) NOT NULL,
    numero character varying(15) NOT NULL,
    fecha_emision date NOT NULL,
    id_empresa integer NOT NULL,
    id_proveedor integer NOT NULL,
    id_sucursal integer,
    regimen character varying(5) NOT NULL,
    tasa numeric(8,4) NOT NULL,
    base_imponible numeric(12,4) DEFAULT 0 NOT NULL,
    monto_retenido numeric(12,4) DEFAULT 0 NOT NULL,
    monto_pagado numeric(12,4) DEFAULT 0 NOT NULL,
    observacion character varying(500),
    id_estado_sunat integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS com_retencion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE com_retencion_id_seq OWNED BY public.com_retencion.id;

ALTER TABLE com_retencion ALTER COLUMN id SET DEFAULT nextval('public.com_retencion_id_seq'::regclass);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_pkey PRIMARY KEY (id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_empresa_serie_numero_key UNIQUE (id_empresa, serie, numero);

CREATE INDEX idx_com_retencion_empresa ON com_retencion USING btree (id_empresa);

CREATE INDEX idx_com_retencion_proveedor ON com_retencion USING btree (id_proveedor);

CREATE INDEX idx_com_retencion_fecha ON com_retencion USING btree (fecha_emision);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);


ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);


-- >>> tablas/compras/com_retencion_detalle.sql
-- Tabla: com_retencion_detalle
-- Detalle de documentos asociados a una retención

CREATE TABLE IF NOT EXISTS com_retencion_detalle (
    id integer NOT NULL,
    id_retencion integer NOT NULL,
    id_compra integer,
    tipo_doc character varying(5) NOT NULL,
    num_doc character varying(30) NOT NULL,
    fecha_emision date NOT NULL,
    fecha_retencion date NOT NULL,
    moneda character varying(5) DEFAULT 'PEN' NOT NULL,
    imp_total numeric(12,4) DEFAULT 0 NOT NULL,
    imp_retenido numeric(12,4) DEFAULT 0 NOT NULL,
    imp_pagar numeric(12,4) DEFAULT 0 NOT NULL,
    tipo_cambio_moneda_ref character varying(5) DEFAULT 'PEN',
    tipo_cambio_moneda_obj character varying(5) DEFAULT 'PEN',
    tipo_cambio_factor numeric(10,6) DEFAULT 1,
    tipo_cambio_fecha date,
    estado integer DEFAULT 1 NOT NULL,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS com_retencion_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE com_retencion_detalle_id_seq OWNED BY public.com_retencion_detalle.id;

ALTER TABLE com_retencion_detalle ALTER COLUMN id SET DEFAULT nextval('public.com_retencion_detalle_id_seq'::regclass);

ALTER TABLE com_retencion_detalle ADD CONSTRAINT com_retencion_detalle_pkey PRIMARY KEY (id);

ALTER TABLE com_retencion_detalle ADD CONSTRAINT com_retencion_detalle_id_retencion_fkey FOREIGN KEY (id_retencion) REFERENCES public.com_retencion(id);

ALTER TABLE com_retencion_detalle ADD CONSTRAINT com_retencion_detalle_id_compra_fkey FOREIGN KEY (id_compra) REFERENCES public.com_comprobante_compra(id);


-- >>> funciones/percepciones/ven_crear_percepcion.sql
-- Function: ven_crear_percepcion
-- Crear un comprobante de percepción con su detalle

CREATE OR REPLACE FUNCTION ven_crear_percepcion(
    p_serie character varying,
    p_fecha_emision date,
    p_id_empresa integer,
    p_id_cliente integer,
    p_id_sucursal integer,
    p_regimen character varying,
    p_tasa numeric,
    p_base_imponible numeric,
    p_monto_percibido numeric,
    p_monto_cobrado numeric,
    p_observacion character varying,
    p_detalles jsonb,
    p_id_usuario_auditoria integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_percepcion_id INTEGER;
    v_detalle JSONB;
    v_item JSONB;
    v_numero VARCHAR;
    v_siguiente BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_empresa IS NULL THEN
        RETURN json_build_object('error', 'La empresa emisora es obligatoria');
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio');
    END IF;

    IF p_regimen IS NULL OR TRIM(p_regimen) = '' THEN
        RETURN json_build_object('error', 'El régimen de percepción es obligatorio');
    END IF;

    IF p_tasa IS NULL OR p_tasa <= 0 THEN
        RETURN json_build_object('error', 'La tasa de percepción debe ser mayor a 0');
    END IF;

    -- Siguiente correlativo por empresa + serie: cada RUC numera aparte en
    -- SUNAT. Se cuentan también los anulados (no se reutilizan números).
    PERFORM pg_advisory_xact_lock(872016, hashtext(p_id_empresa::TEXT || '|' || UPPER(TRIM(p_serie))));

    SELECT COALESCE(MAX(numero::BIGINT), 0) INTO v_siguiente
    FROM ven_percepcion
    WHERE id_empresa = p_id_empresa
      AND UPPER(TRIM(serie)) = UPPER(TRIM(p_serie))
      AND numero ~ '^[0-9]+$';

    v_numero := LPAD((v_siguiente + 1)::TEXT, 8, '0');

    -- Insertar cabecera
    INSERT INTO ven_percepcion (
        serie, numero, fecha_emision, id_empresa, id_cliente, id_sucursal,
        regimen, tasa, base_imponible, monto_percibido, monto_cobrado,
        observacion, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        UPPER(TRIM(p_serie)), v_numero, p_fecha_emision, p_id_empresa, p_id_cliente, p_id_sucursal,
        TRIM(p_regimen), p_tasa, p_base_imponible, p_monto_percibido, p_monto_cobrado,
        p_observacion, p_id_usuario_auditoria, p_id_usuario_auditoria
    ) RETURNING id INTO v_percepcion_id;

    -- Insertar detalle
    IF p_detalles IS NOT NULL AND jsonb_array_length(p_detalles) > 0 THEN
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles)
        LOOP
            INSERT INTO ven_percepcion_detalle (
                id_percepcion, id_comprobante, tipo_doc, num_doc,
                fecha_emision, fecha_percepcion, moneda,
                imp_total, imp_percibido, imp_cobrar,
                tipo_cambio_moneda_ref, tipo_cambio_moneda_obj,
                tipo_cambio_factor, tipo_cambio_fecha
            ) VALUES (
                v_percepcion_id,
                NULLIF((v_item->>'id_comprobante')::integer, 0),
                COALESCE(NULLIF(TRIM(v_item->>'tipo_doc'), ''), '01'),
                COALESCE(v_item->>'num_doc', ''),
                COALESCE((v_item->>'fecha_emision')::date, CURRENT_DATE),
                COALESCE((v_item->>'fecha_percepcion')::date, CURRENT_DATE),
                COALESCE(NULLIF(TRIM(v_item->>'moneda'), ''), 'PEN'),
                COALESCE((v_item->>'imp_total')::numeric, 0),
                COALESCE((v_item->>'imp_percibido')::numeric, 0),
                COALESCE((v_item->>'imp_cobrar')::numeric, 0),
                COALESCE(NULLIF(TRIM(v_item->>'tipo_cambio_moneda_ref'), ''), 'PEN'),
                COALESCE(NULLIF(TRIM(v_item->>'tipo_cambio_moneda_obj'), ''), 'PEN'),
                COALESCE((v_item->>'tipo_cambio_factor')::numeric, 1),
                (v_item->>'tipo_cambio_fecha')::date
            );
        END LOOP;
    END IF;

    RETURN json_build_object(
        'id', v_percepcion_id,
        'serie', UPPER(TRIM(p_serie)),
        'numero', v_numero
    );
END;
$function$;


-- >>> funciones/percepciones/ven_listar_percepciones.sql
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


-- >>> funciones/percepciones/ven_obtener_percepcion.sql
-- Function: ven_obtener_percepcion
-- Obtener una percepción con su detalle

CREATE OR REPLACE FUNCTION ven_obtener_percepcion(p_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_percepcion JSONB;
    v_detalles JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Además de la fila: nombre del estado SUNAT y del cliente (cli_clientes),
    -- que la pantalla y el payload necesitan sin consultas adicionales.
    SELECT to_jsonb(p.*) || jsonb_build_object(
        'nombre_estado_sunat', es.nombre,
        'nombre_cliente', COALESCE(NULLIF(TRIM(c.razon_social), ''),
                            NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')),
        'documento_cliente', c.numero_documento,
        'tipo_documento_cliente', td.nombre
    ) INTO v_percepcion
    FROM ven_percepcion p
    LEFT JOIN gen_lista_opciones es ON es.id = p.id_estado_sunat
    LEFT JOIN cli_clientes c ON c.id = p.id_cliente
    LEFT JOIN gen_lista_opciones td ON td.id = c.id_tipo_documento
    WHERE p.id = p_id AND p.estado = 1;

    IF v_percepcion IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Percepción no encontrada');
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(d.*)), '[]'::jsonb) INTO v_detalles
    FROM ven_percepcion_detalle d
    WHERE d.id_percepcion = p_id AND d.estado = 1;

    v_percepcion := v_percepcion || jsonb_build_object('detalles', v_detalles);

    RETURN json_build_object('registro', v_percepcion);
END;
$function$;


-- >>> funciones/percepciones/ven_registrar_respuesta_sunat_percepcion.sql
-- Function: ven_registrar_respuesta_sunat_percepcion
-- Registrar respuesta de SUNAT para una percepción

CREATE OR REPLACE FUNCTION ven_registrar_respuesta_sunat_percepcion(
    p_id integer,
    p_id_estado_sunat integer DEFAULT NULL,
    p_ticket_sunat character varying DEFAULT NULL,
    p_hash_documento character varying DEFAULT NULL,
    p_xml_firmado text DEFAULT NULL,
    p_cdr_respuesta text DEFAULT NULL,
    p_id_usuario_auditoria integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM ven_percepcion WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE ven_percepcion
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN ven_obtener_percepcion(p_id);
END;
$function$;


-- >>> funciones/retenciones/com_crear_retencion.sql
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


-- >>> funciones/retenciones/com_listar_retenciones.sql
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


-- >>> funciones/retenciones/com_obtener_retencion.sql
-- Function: com_obtener_retencion
-- Obtener una retención con su detalle

CREATE OR REPLACE FUNCTION com_obtener_retencion(p_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_retencion JSONB;
    v_detalles JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Además de la fila: nombre del estado SUNAT y del proveedor (cli_clientes),
    -- que la pantalla y el payload necesitan sin consultas adicionales.
    SELECT to_jsonb(r.*) || jsonb_build_object(
        'nombre_estado_sunat', es.nombre,
        'nombre_proveedor', COALESCE(NULLIF(TRIM(c.razon_social), ''),
                              NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')),
        'documento_proveedor', c.numero_documento,
        'tipo_documento_proveedor', td.nombre
    ) INTO v_retencion
    FROM com_retencion r
    LEFT JOIN gen_lista_opciones es ON es.id = r.id_estado_sunat
    LEFT JOIN cli_clientes c ON c.id = r.id_proveedor
    LEFT JOIN gen_lista_opciones td ON td.id = c.id_tipo_documento
    WHERE r.id = p_id AND r.estado = 1;

    IF v_retencion IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Retención no encontrada');
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(d.*)), '[]'::jsonb) INTO v_detalles
    FROM com_retencion_detalle d
    WHERE d.id_retencion = p_id AND d.estado = 1;

    v_retencion := v_retencion || jsonb_build_object('detalles', v_detalles);

    RETURN json_build_object('registro', v_retencion);
END;
$function$;


-- >>> funciones/retenciones/com_registrar_respuesta_sunat_retencion.sql
-- Function: com_registrar_respuesta_sunat_retencion
-- Registrar respuesta de SUNAT para una retención

CREATE OR REPLACE FUNCTION com_registrar_respuesta_sunat_retencion(
    p_id integer,
    p_id_estado_sunat integer DEFAULT NULL,
    p_ticket_sunat character varying DEFAULT NULL,
    p_hash_documento character varying DEFAULT NULL,
    p_xml_firmado text DEFAULT NULL,
    p_cdr_respuesta text DEFAULT NULL,
    p_id_usuario_auditoria integer DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM com_retencion WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE com_retencion
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN com_obtener_retencion(p_id);
END;
$function$;


-- >>> seeds/percepciones_retenciones_lista_opciones.sql
-- Catálogos SUNAT para comprobantes de percepción (catálogo 22) y retención
-- (catálogo 23). Igual que TipoGuiaRemision: el código SUNAT va en
-- `descripcion` y la etiqueta en `nombre` (gen_lista_opciones no tiene
-- columnas codigo/orden).

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('RegimenPercepcion', 'Catálogo 22 SUNAT — régimen de percepción (código en descripcion)'),
        ('RegimenRetencion', 'Catálogo 23 SUNAT — régimen de retención (código en descripcion)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre);

-- Catálogo 22: régimen de percepción. La tasa la fija SUNAT por régimen.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', 'Percepción venta interna (2%)'),
    ('02', 'Percepción a la adquisición de combustible (1%)'),
    ('03', 'Percepción realizada al agente de percepción con tasa especial (0.5%)')
) AS v(codigo, nombre)
WHERE l.nombre = 'RegimenPercepcion'
  AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones o WHERE o.id_lista = l.id AND o.descripcion = v.codigo);

-- Catálogo 23: régimen de retención.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', 'Tasa 3%'),
    ('02', 'Tasa 6%')
) AS v(codigo, nombre)
WHERE l.nombre = 'RegimenRetencion'
  AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones o WHERE o.id_lista = l.id AND o.descripcion = v.codigo);

-- Permisos de ambos módulos (mismo patrón que doc_permisos_banderas.sql).
INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('percepciones.listar', 'Listar comprobantes de percepción'),
        ('percepciones.ver', 'Ver detalle de un comprobante de percepción'),
        ('percepciones.crear', 'Crear comprobantes de percepción'),
        ('percepciones.editar', 'Editar comprobantes de percepción'),
        ('percepciones.eliminar', 'Anular comprobantes de percepción'),
        ('percepciones.emitir', 'Emitir percepciones a SUNAT y descargar PDF/XML oficial'),
        ('retenciones.listar', 'Listar comprobantes de retención'),
        ('retenciones.ver', 'Ver detalle de un comprobante de retención'),
        ('retenciones.crear', 'Crear comprobantes de retención'),
        ('retenciones.editar', 'Editar comprobantes de retención'),
        ('retenciones.eliminar', 'Anular comprobantes de retención'),
        ('retenciones.emitir', 'Emitir retenciones a SUNAT y descargar PDF/XML oficial')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND (p.nombre LIKE 'percepciones.%' OR p.nombre LIKE 'retenciones.%')
  AND NOT EXISTS (SELECT 1 FROM auth_roles_permisos rp WHERE rp.id_rol = r.id AND rp.id_permiso = p.id);

COMMIT;
