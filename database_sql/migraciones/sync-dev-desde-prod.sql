-- Lleva a DEV lo elegido de PROD: tablas y columnas solo de PROD, funciones con origen prod y catálogos asociados.
-- Respaldar la base de DEV antes de aplicarlo.
-- No ejecutar sin revisión: generado por database_sql/scripts/generar-sync.js.
-- Funciones pendientes no incluidas (ven_obtener_siguiente_numero): ver database_sql/.cache/reporte-funciones.md
BEGIN;

CREATE TABLE IF NOT EXISTS public.ven_comprobante_historial_cpe (
  id bigint NOT NULL,
  id_comprobante integer NOT NULL,
  serie character varying(10) NOT NULL,
  numero character varying(15) NOT NULL,
  datos_originales jsonb NOT NULL,
  verificacion_sunat jsonb NOT NULL,
  serie_nueva character varying(10) NOT NULL,
  numero_nuevo character varying(15) NOT NULL,
  fecha_emision_nueva date NOT NULL,
  id_usuario_creacion integer,
  fecha_creacion timestamp with time zone DEFAULT now() NOT NULL
);

CREATE SEQUENCE IF NOT EXISTS public.ven_comprobante_historial_cpe_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_comprobante_historial_cpe_id_seq OWNED BY public.ven_comprobante_historial_cpe.id;

ALTER TABLE ONLY public.ven_comprobante_historial_cpe
ALTER COLUMN id
SET DEFAULT nextval(
  'public.ven_comprobante_historial_cpe_id_seq'::regclass
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_comprobante_historial_cpe'::regclass AND conname = 'ven_comprobante_historial_cpe_pkey') THEN
    ALTER TABLE ONLY public.ven_comprobante_historial_cpe
    ADD CONSTRAINT ven_comprobante_historial_cpe_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_comprobante_historial_cpe'::regclass AND conname = 'ven_comprobante_historial_cpe_serie_numero_key') THEN
    ALTER TABLE ONLY public.ven_comprobante_historial_cpe
    ADD CONSTRAINT ven_comprobante_historial_cpe_serie_numero_key UNIQUE (serie, numero);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_cpe_correccion_intento (
  id bigint NOT NULL,
  id_nota bigint NOT NULL,
  iniciado_en timestamp with time zone DEFAULT now() NOT NULL,
  terminado_en timestamp with time zone,
  resultado jsonb
);

CREATE SEQUENCE IF NOT EXISTS public.ven_cpe_correccion_intento_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_cpe_correccion_intento_id_seq OWNED BY public.ven_cpe_correccion_intento.id;

ALTER TABLE ONLY public.ven_cpe_correccion_intento
ALTER COLUMN id
SET DEFAULT nextval(
  'public.ven_cpe_correccion_intento_id_seq'::regclass
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_intento'::regclass AND conname = 'ven_cpe_correccion_intento_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_intento
    ADD CONSTRAINT ven_cpe_correccion_intento_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_cpe_correccion_lote (
  id uuid NOT NULL,
  motivo text NOT NULL,
  estado character varying(40) DEFAULT 'PREPARADO'::character varying NOT NULL,
  fecha_fiscal date NOT NULL,
  plan jsonb NOT NULL,
  creado_en timestamp with time zone DEFAULT now() NOT NULL,
  actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
  numeracion_bloqueada boolean DEFAULT FALSE NOT NULL,
  numeracion_bloqueada_en timestamp with time zone,
  motivo_bloqueo text
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_lote'::regclass AND conname = 'ven_cpe_correccion_lote_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_lote
    ADD CONSTRAINT ven_cpe_correccion_lote_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_cpe_correccion_nota (
  id bigint NOT NULL,
  id_lote uuid NOT NULL,
  id_empresa integer NOT NULL,
  id_comprobante_original integer NOT NULL,
  serie_original character varying(4) NOT NULL,
  numero_original character varying(8) NOT NULL,
  serie character varying(4) NOT NULL,
  numero integer NOT NULL,
  importe numeric(18, 2) NOT NULL,
  estado character varying(40) DEFAULT 'PREPARADO'::character varying NOT NULL,
  payload jsonb NOT NULL,
  xml_firmado text,
  hash_documento text,
  cdr_respuesta jsonb,
  verificacion_original jsonb NOT NULL,
  datos_originales jsonb NOT NULL,
  creado_en timestamp with time zone DEFAULT now() NOT NULL,
  actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT ven_cpe_correccion_nota_importe_check CHECK ((importe > (0)::numeric)),
  CONSTRAINT ven_cpe_correccion_nota_numero_check CHECK ((numero > 0)),
  CONSTRAINT ven_cpe_correccion_nota_serie_check CHECK (
    (
      (serie)::text = ANY (
        (
          ARRAY[
            'FC02'::character varying,
            'BC02'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

CREATE SEQUENCE IF NOT EXISTS public.ven_cpe_correccion_nota_id_seq START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.ven_cpe_correccion_nota_id_seq OWNED BY public.ven_cpe_correccion_nota.id;

ALTER TABLE ONLY public.ven_cpe_correccion_nota
ALTER COLUMN id
SET DEFAULT nextval('public.ven_cpe_correccion_nota_id_seq'::regclass);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_nota'::regclass AND conname = 'ven_cpe_correccion_nota_id_empresa_serie_numero_key') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_nota
    ADD CONSTRAINT ven_cpe_correccion_nota_id_empresa_serie_numero_key UNIQUE (id_empresa, serie, numero);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_nota'::regclass AND conname = 'ven_cpe_correccion_nota_id_lote_id_comprobante_original_key') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_nota
    ADD CONSTRAINT ven_cpe_correccion_nota_id_lote_id_comprobante_original_key UNIQUE (id_lote, id_comprobante_original);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_nota'::regclass AND conname = 'ven_cpe_correccion_nota_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_nota
    ADD CONSTRAINT ven_cpe_correccion_nota_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

CREATE INDEX IF NOT EXISTS ix_correccion_nota_venta ON public.ven_cpe_correccion_nota USING btree (id_comprobante_original);

CREATE TABLE IF NOT EXISTS public.ven_cpe_correccion_reemplazo (
  id_lote uuid NOT NULL,
  id_comprobante integer NOT NULL,
  serie character varying(4) NOT NULL,
  numero character varying(8) NOT NULL,
  payload jsonb NOT NULL,
  xml_firmado text,
  respuesta jsonb,
  estado character varying(40) DEFAULT 'PREPARADO'::character varying NOT NULL,
  intentos integer DEFAULT 0 NOT NULL,
  actualizado_en timestamp with time zone DEFAULT now() NOT NULL
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reemplazo'::regclass AND conname = 'ven_cpe_correccion_reemplazo_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
    ADD CONSTRAINT ven_cpe_correccion_reemplazo_pkey PRIMARY KEY (id_lote, id_comprobante);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reemplazo'::regclass AND conname = 'ven_cpe_correccion_reemplazo_serie_numero_key') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
    ADD CONSTRAINT ven_cpe_correccion_reemplazo_serie_numero_key UNIQUE (serie, numero);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_cpe_correccion_reserva (
  serie character varying(4) NOT NULL,
  numero integer NOT NULL,
  id_lote uuid NOT NULL,
  id_comprobante integer NOT NULL,
  creado_en timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT ven_cpe_correccion_reserva_numero_check CHECK ((numero > 0)),
  CONSTRAINT ven_cpe_correccion_reserva_serie_check CHECK (
    (
      (serie)::text = ANY (
        (
          ARRAY[
            'F002'::character varying,
            'B002'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reserva'::regclass AND conname = 'ven_cpe_correccion_reserva_id_lote_id_comprobante_key') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reserva
    ADD CONSTRAINT ven_cpe_correccion_reserva_id_lote_id_comprobante_key UNIQUE (id_lote, id_comprobante);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reserva'::regclass AND conname = 'ven_cpe_correccion_reserva_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reserva
    ADD CONSTRAINT ven_cpe_correccion_reserva_pkey PRIMARY KEY (serie, numero);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_cpe_operacion_control (
  id_empresa integer NOT NULL,
  token uuid NOT NULL,
  vencimiento timestamp with time zone NOT NULL
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_operacion_control'::regclass AND conname = 'ven_cpe_operacion_control_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_operacion_control
    ADD CONSTRAINT ven_cpe_operacion_control_pkey PRIMARY KEY (id_empresa);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_cpe_verificacion_control (
  id smallint NOT NULL,
  token uuid NOT NULL,
  vencimiento timestamp with time zone NOT NULL,
  CONSTRAINT ven_cpe_verificacion_control_id_check CHECK ((id = 1))
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_verificacion_control'::regclass AND conname = 'ven_cpe_verificacion_control_pkey') THEN
    ALTER TABLE ONLY public.ven_cpe_verificacion_control
    ADD CONSTRAINT ven_cpe_verificacion_control_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

CREATE TABLE IF NOT EXISTS public.ven_vsd_operacion (
  id bigint NOT NULL,
  id_comprobante integer NOT NULL,
  tipo character varying(20) NOT NULL,
  solicitud uuid,
  motivo character varying(500) NOT NULL,
  datos jsonb NOT NULL,
  anterior jsonb NOT NULL,
  posterior jsonb NOT NULL,
  id_usuario integer NOT NULL,
  fecha timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT ven_vsd_operacion_motivo_check CHECK ((length(btrim((motivo)::text)) >= 5)),
  CONSTRAINT ven_vsd_operacion_tipo_check CHECK (
    (
      (tipo)::text = ANY (
        (
          ARRAY[
            'CORRECCION'::character varying,
            'CAMBIO_BALON'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid = 'public.ven_vsd_operacion'::regclass AND attname = 'id' AND attidentity <> '') THEN
    ALTER TABLE public.ven_vsd_operacion
    ALTER COLUMN id
    ADD GENERATED ALWAYS AS IDENTITY (
      SEQUENCE NAME public.ven_vsd_operacion_id_seq START
      WITH
        1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1
    );
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_vsd_operacion'::regclass AND conname = 'ven_vsd_operacion_pkey') THEN
    ALTER TABLE ONLY public.ven_vsd_operacion
    ADD CONSTRAINT ven_vsd_operacion_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_vsd_operacion'::regclass AND conname = 'ven_vsd_operacion_solicitud_key') THEN
    ALTER TABLE ONLY public.ven_vsd_operacion
    ADD CONSTRAINT ven_vsd_operacion_solicitud_key UNIQUE (solicitud);
  END IF;
END
$sync$;

CREATE INDEX IF NOT EXISTS idx_vsd_operacion_venta ON public.ven_vsd_operacion USING btree (id_comprobante, id);

ALTER TABLE public.gen_configuracion_sunat
ADD COLUMN IF NOT EXISTS validez_client_id character varying(255);

COMMENT ON COLUMN public.gen_configuracion_sunat.validez_client_id IS 'Client ID de consulta integrada de validez CPE (no GRE)';

ALTER TABLE public.gen_configuracion_sunat
ADD COLUMN IF NOT EXISTS validez_client_secret character varying(255);

COMMENT ON COLUMN public.gen_configuracion_sunat.validez_client_secret IS 'Client Secret de consulta integrada de validez CPE; no exponer por HTTP';

ALTER TABLE public.ven_comprobante
ADD COLUMN IF NOT EXISTS fecha_emision_cpe date;

ALTER TABLE public.ven_comprobante
ADD COLUMN IF NOT EXISTS validez_sunat jsonb;

ALTER TABLE public.ven_comprobante
ADD COLUMN IF NOT EXISTS cpe_verificacion jsonb;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_comprobante_historial_cpe'::regclass AND conname = 'ven_comprobante_historial_cpe_id_comprobante_fkey') THEN
    ALTER TABLE ONLY public.ven_comprobante_historial_cpe
    ADD CONSTRAINT ven_comprobante_historial_cpe_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_comprobante_historial_cpe'::regclass AND conname = 'ven_comprobante_historial_cpe_id_usuario_creacion_fkey') THEN
    ALTER TABLE ONLY public.ven_comprobante_historial_cpe
    ADD CONSTRAINT ven_comprobante_historial_cpe_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_intento'::regclass AND conname = 'ven_cpe_correccion_intento_id_nota_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_intento
    ADD CONSTRAINT ven_cpe_correccion_intento_id_nota_fkey FOREIGN KEY (id_nota) REFERENCES public.ven_cpe_correccion_nota (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_nota'::regclass AND conname = 'ven_cpe_correccion_nota_id_comprobante_original_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_nota
    ADD CONSTRAINT ven_cpe_correccion_nota_id_comprobante_original_fkey FOREIGN KEY (id_comprobante_original) REFERENCES public.ven_comprobante (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_nota'::regclass AND conname = 'ven_cpe_correccion_nota_id_empresa_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_nota
    ADD CONSTRAINT ven_cpe_correccion_nota_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_nota'::regclass AND conname = 'ven_cpe_correccion_nota_id_lote_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_nota
    ADD CONSTRAINT ven_cpe_correccion_nota_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.ven_cpe_correccion_lote (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reemplazo'::regclass AND conname = 'ven_cpe_correccion_reemplazo_id_comprobante_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
    ADD CONSTRAINT ven_cpe_correccion_reemplazo_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reemplazo'::regclass AND conname = 'ven_cpe_correccion_reemplazo_id_lote_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reemplazo
    ADD CONSTRAINT ven_cpe_correccion_reemplazo_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.ven_cpe_correccion_lote (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reserva'::regclass AND conname = 'ven_cpe_correccion_reserva_id_comprobante_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reserva
    ADD CONSTRAINT ven_cpe_correccion_reserva_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_correccion_reserva'::regclass AND conname = 'ven_cpe_correccion_reserva_id_lote_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_correccion_reserva
    ADD CONSTRAINT ven_cpe_correccion_reserva_id_lote_fkey FOREIGN KEY (id_lote) REFERENCES public.ven_cpe_correccion_lote (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_cpe_operacion_control'::regclass AND conname = 'ven_cpe_operacion_control_id_empresa_fkey') THEN
    ALTER TABLE ONLY public.ven_cpe_operacion_control
    ADD CONSTRAINT ven_cpe_operacion_control_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_vsd_operacion'::regclass AND conname = 'ven_vsd_operacion_id_comprobante_fkey') THEN
    ALTER TABLE ONLY public.ven_vsd_operacion
    ADD CONSTRAINT ven_vsd_operacion_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante (id);
  END IF;
END
$sync$;

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.ven_vsd_operacion'::regclass AND conname = 'ven_vsd_operacion_id_usuario_fkey') THEN
    ALTER TABLE ONLY public.ven_vsd_operacion
    ADD CONSTRAINT ven_vsd_operacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.auth_usuarios (id);
  END IF;
END
$sync$;

DROP FUNCTION IF EXISTS public.dash_demanda_gases (p_fecha_desde date, p_fecha_hasta date);

CREATE OR REPLACE FUNCTION public.dash_demanda_gases (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH detalle_gas AS (
        SELECT
            p.id AS id_producto,
            p.nombre,
            SUM(vcd.cantidad) AS cantidad
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        JOIN pro_producto p ON p.id = vcd.id_producto
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND (p_fecha_desde IS NULL OR vc.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR vc.fecha <= p_fecha_hasta)
        GROUP BY p.id, p.nombre
    ),
    totales AS (
        SELECT COALESCE(SUM(cantidad), 0) AS total FROM detalle_gas
    )
    SELECT json_build_object(
        'totalCantidad', (SELECT total FROM totales),
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idProducto', d.id_producto,
                'producto', d.nombre,
                'cantidad', d.cantidad,
                'porcentaje', CASE WHEN t.total > 0 THEN ROUND(d.cantidad / t.total * 100, 2) ELSE 0 END
            )
            ORDER BY d.cantidad DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM detalle_gas d
    CROSS JOIN totales t;

    RETURN v_result;
END;
$function$;

DROP FUNCTION IF EXISTS public.dash_historico_ventas_compras (p_anio integer);

CREATE OR REPLACE FUNCTION public.dash_historico_ventas_compras (p_anio integer DEFAULT NULL::integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_anio   INT := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH meses AS (
        SELECT generate_series(1, 12) AS mes
    ),
    ventas AS (
        SELECT EXTRACT(MONTH FROM vc.fecha)::INT AS mes, SUM(vc.total_importe) AS total
        FROM ven_comprobante vc
        WHERE vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND EXTRACT(YEAR FROM vc.fecha) = v_anio
        GROUP BY 1
    ),
    compras AS (
        SELECT EXTRACT(MONTH FROM cc.fecha)::INT AS mes, SUM(cc.total_importe) AS total
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND EXTRACT(YEAR FROM cc.fecha) = v_anio
        GROUP BY 1
    )
    SELECT json_build_object(
        'anio', v_anio,
        'meses', json_agg(
            json_build_object(
                'mes', m.mes,
                'nombreMes', TO_CHAR(TO_DATE(m.mes::text, 'MM'), 'Mon'),
                'ventas', COALESCE(v.total, 0),
                'compras', COALESCE(c.total, 0)
            )
            ORDER BY m.mes
        )
    )
    INTO v_result
    FROM meses m
    LEFT JOIN ventas v ON v.mes = m.mes
    LEFT JOIN compras c ON c.mes = m.mes;

    RETURN v_result;
END;
$function$;

DROP FUNCTION IF EXISTS public.dash_top_clientes_venta (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_limite integer
);

CREATE OR REPLACE FUNCTION public.dash_top_clientes_venta (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_limite integer DEFAULT 10
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_desde  DATE := COALESCE(p_fecha_desde, DATE_TRUNC('month', CURRENT_DATE)::date);
    v_hasta  DATE := COALESCE(p_fecha_hasta, (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::date);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(json_agg(t), '[]'::json)
    INTO v_result
    FROM (
        SELECT
            c.id AS "idCliente",
            COALESCE(c.razon_social, c.nombres) AS cliente,
            COUNT(DISTINCT vc.id) AS "cantidadComprobantes",
            SUM(vc.total_importe) AS "totalVenta"
        FROM ven_comprobante vc
        JOIN cli_clientes c ON c.id = vc.id_cliente
        WHERE vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND vc.fecha >= v_desde
          AND vc.fecha <= v_hasta
        GROUP BY c.id, c.razon_social, c.nombres
        ORDER BY SUM(vc.total_importe) DESC
        LIMIT p_limite
    ) t;

    RETURN json_build_object(
        'fechaDesde', v_desde,
        'fechaHasta', v_hasta,
        'detalle', v_result
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.dash_velocidad_salida (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_almacen integer,
  p_limite integer
);

CREATE OR REPLACE FUNCTION public.dash_velocidad_salida (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_almacen integer DEFAULT NULL::integer,
  p_limite integer DEFAULT 20
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH stock_prod AS (
        SELECT
            s.id_producto,
            SUM(s.stock) AS stock_actual
        FROM pro_stock s
        WHERE s.estado = 1
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
        GROUP BY s.id_producto
    ),
    ventas_prod AS (
        SELECT
            vcd.id_producto,
            SUM(vcd.cantidad) AS cantidad_vendida
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND (p_fecha_desde IS NULL OR vc.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR vc.fecha <= p_fecha_hasta)
        GROUP BY vcd.id_producto
    ),
    calculo AS (
        SELECT
            p.id AS id_producto,
            p.nombre AS producto,
            COALESCE(c.nombre, 'Sin categoría') AS categoria,
            COALESCE(sp.stock_actual, 0) AS stock_actual,
            COALESCE(vp.cantidad_vendida, 0) AS cantidad_vendida,
            CASE WHEN COALESCE(sp.stock_actual, 0) > 0
                THEN ROUND(COALESCE(vp.cantidad_vendida, 0) / sp.stock_actual, 2)
                ELSE NULL
            END AS rotacion,
            CASE WHEN p.precio > 0
                THEN ROUND((p.precio - p.precio_compra) / p.precio * 100, 2)
                ELSE NULL
            END AS margen_unitario
        FROM pro_producto p
        LEFT JOIN pro_sub_categoria sc ON sc.id = p.id_sub_categoria
        LEFT JOIN pro_categoria c ON c.id = sc.id_categoria
        LEFT JOIN stock_prod sp ON sp.id_producto = p.id
        LEFT JOIN ventas_prod vp ON vp.id_producto = p.id
        WHERE p.estado = 1
          AND COALESCE(p.es_servicio, FALSE) = FALSE
          AND COALESCE(p.afecta_stock, TRUE) = TRUE
    )
    SELECT COALESCE(json_agg(t), '[]'::json)
    INTO v_result
    FROM (
        SELECT
            id_producto AS "idProducto",
            producto,
            categoria,
            stock_actual AS "stockActual",
            cantidad_vendida AS "cantidadVendida",
            rotacion,
            CASE
                WHEN rotacion IS NULL THEN 'SIN_STOCK'
                WHEN rotacion >= 8 THEN 'MUY_ALTA'
                WHEN rotacion >= 4 THEN 'ALTA'
                WHEN rotacion >= 1.5 THEN 'MEDIA'
                ELSE 'BAJA'
            END AS "nivelRotacion",
            margen_unitario AS "margenUnitario"
        FROM calculo
        ORDER BY rotacion DESC NULLS LAST
        LIMIT p_limite
    ) t;

    RETURN json_build_object('detalle', v_result);
END;
$function$;

DROP FUNCTION IF EXISTS public.dash_venta_gases_comparativo (p_anio integer, p_mes integer);

CREATE OR REPLACE FUNCTION public.dash_venta_gases_comparativo (
  p_anio integer DEFAULT NULL::integer,
  p_mes integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_fecha_ref     DATE;
    v_inicio_actual DATE;
    v_fin_actual    DATE;
    v_inicio_ant    DATE;
    v_fin_ant       DATE;
    v_result        JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_fecha_ref := MAKE_DATE(
        COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INT),
        COALESCE(p_mes, EXTRACT(MONTH FROM CURRENT_DATE)::INT),
        1
    );

    v_inicio_actual := DATE_TRUNC('month', v_fecha_ref)::date;
    v_fin_actual    := (DATE_TRUNC('month', v_fecha_ref) + INTERVAL '1 month - 1 day')::date;
    v_inicio_ant    := (DATE_TRUNC('month', v_fecha_ref) - INTERVAL '1 month')::date;
    v_fin_ant       := (v_inicio_actual - INTERVAL '1 day')::date;

    WITH ventas_gas AS (
        SELECT
            p.id AS id_producto,
            p.nombre,
            SUM(vcd.cantidad) FILTER (WHERE vc.fecha BETWEEN v_inicio_actual AND v_fin_actual) AS cantidad_actual,
            SUM(vcd.cantidad) FILTER (WHERE vc.fecha BETWEEN v_inicio_ant AND v_fin_ant) AS cantidad_anterior
        FROM ven_comprobante_detalle vcd
        JOIN ven_comprobante vc ON vc.id = vcd.id_comprobante
        JOIN pro_producto p ON p.id = vcd.id_producto
        WHERE vcd.estado = 1
          AND vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND COALESCE(p.es_gas, FALSE) = TRUE
          AND vc.fecha BETWEEN v_inicio_ant AND v_fin_actual
        GROUP BY p.id, p.nombre
    )
    SELECT json_build_object(
        'mesActual', json_build_object('anio', EXTRACT(YEAR FROM v_inicio_actual), 'mes', EXTRACT(MONTH FROM v_inicio_actual)),
        'mesAnterior', json_build_object('anio', EXTRACT(YEAR FROM v_inicio_ant), 'mes', EXTRACT(MONTH FROM v_inicio_ant)),
        'detalle', COALESCE(json_agg(
            json_build_object(
                'idProducto', id_producto,
                'producto', nombre,
                'cantidadActual', COALESCE(cantidad_actual, 0),
                'cantidadAnterior', COALESCE(cantidad_anterior, 0)
            )
            ORDER BY COALESCE(cantidad_actual, 0) DESC
        ), '[]'::json)
    )
    INTO v_result
    FROM ventas_gas;

    RETURN v_result;
END;
$function$;

DROP FUNCTION IF EXISTS public.dash_ventas_netas (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_cliente integer
);

CREATE OR REPLACE FUNCTION public.dash_ventas_netas (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer
) RETURNS numeric LANGUAGE plpgsql AS $function$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COALESCE(SUM(total_importe), 0)
    INTO v_total
    FROM ven_comprobante vc
    WHERE vc.estado = 1
      AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
      AND (p_fecha_desde IS NULL OR fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR fecha <= p_fecha_hasta)
      AND (p_id_cliente IS NULL OR id_cliente = p_id_cliente);

    RETURN v_total;
END;
$function$;

DROP FUNCTION IF EXISTS public.doc_listar_series_gre (p_id_tipo_guia_remision integer);

CREATE OR REPLACE FUNCTION public.doc_listar_series_gre (
  p_id_tipo_guia_remision integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_codigo_tipo VARCHAR;
    v_prefijo VARCHAR;
    v_serie_default VARCHAR;
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_guia_remision IS NOT NULL THEN
        SELECT TRIM(lo.descripcion)
        INTO v_codigo_tipo
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_guia_remision;
    END IF;

    v_prefijo := CASE WHEN v_codigo_tipo = '31' THEN 'V' ELSE 'T' END;
    v_serie_default := CASE WHEN v_codigo_tipo = '31' THEN 'V001' ELSE 'T002' END;

    WITH usadas AS (
        SELECT
            UPPER(TRIM(d.serie)) AS serie,
            MAX(NULLIF(REGEXP_REPLACE(d.numero_sunat, '\D', '', 'g'), '')::INTEGER) AS ultimo,
            COUNT(*)::INTEGER AS total
        FROM doc_salida d
        WHERE d.serie IS NOT NULL
          AND d.numero_sunat IS NOT NULL
        GROUP BY UPPER(TRIM(d.serie))
    ),
    series AS (
        SELECT u.serie, u.ultimo, u.total
        FROM usadas u
        WHERE u.serie LIKE v_prefijo || '%'
        UNION ALL
        SELECT v_serie_default, NULL::INTEGER, 0
        WHERE NOT EXISTS (SELECT 1 FROM usadas u WHERE u.serie = v_serie_default)
    )
    SELECT json_agg(
        json_build_object(
            'serie', s.serie,
            'ultimo_numero', CASE WHEN s.ultimo IS NULL THEN NULL ELSE LPAD(s.ultimo::TEXT, 8, '0') END,
            'siguiente_numero', LPAD((COALESCE(s.ultimo, 0) + 1)::TEXT, 8, '0'),
            'total', s.total
        )
        ORDER BY CASE WHEN s.serie = v_serie_default THEN 0 ELSE 1 END, s.serie
    )
    INTO v_resultado
    FROM series s;

    RETURN COALESCE(v_resultado, '[]'::json);
END;
$function$;

DROP FUNCTION IF EXISTS public.gen_listar_configuraciones_sunat (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_empresa integer
);

CREATE OR REPLACE FUNCTION public.gen_listar_configuraciones_sunat (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_empresa integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_configuracion_sunat cs
    INNER JOIN gen_empresa e ON cs.id_empresa = e.id
    LEFT JOIN gen_lista_opciones lo ON cs.id_ambiente = lo.id
    WHERE cs.estado = 1
      AND (p_id_empresa IS NULL OR cs.id_empresa = p_id_empresa)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(cs.usuario_sol, p_busqueda)
          OR gen_texto_coincide(COALESCE(e.nombre_comercial, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lo.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cs.proveedor_pse, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cs.id,
            cs.id_empresa,
            e.nombre_comercial,
            e.ruc AS ruc_empresa,
            cs.usuario_sol,
            cs.clave_sol,
            cs.certificado_digital,
            cs.clave_certificado,
            (cs.clave_sol IS NOT NULL AND TRIM(cs.clave_sol) <> '') AS tiene_clave_sol,
            (cs.clave_certificado IS NOT NULL AND TRIM(cs.clave_certificado) <> '') AS tiene_clave_certificado,
            cs.id_ambiente,
            lo.nombre AS nombre_ambiente,
            cs.proveedor_pse,
            cs.pse_habilitado,
            cs.api_base_url,
            cs.api_token,
            (cs.api_token IS NOT NULL AND TRIM(cs.api_token) <> '') AS tiene_api_token,
            cs.api_usuario,
            cs.api_clave,
            (cs.api_clave IS NOT NULL AND TRIM(cs.api_clave) <> '') AS tiene_api_clave,
            COALESCE(NULLIF(TRIM(cs.ruc_emisor), ''), e.ruc) AS ruc_emisor,
            cs.validez_client_id,
            (NULLIF(TRIM(cs.validez_client_secret), '') IS NOT NULL) AS tiene_validez_client_secret,
            cs.client_id,
            cs.client_secret,
            (cs.client_secret IS NOT NULL AND TRIM(cs.client_secret) <> '') AS tiene_client_secret,
            cs.timeout_ms,
            cs.estado,
            cs.fecha_creacion,
            cs.fecha_modificacion,
            cs.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cs.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_configuracion_sunat cs
        INNER JOIN gen_empresa e ON cs.id_empresa = e.id
        LEFT JOIN gen_lista_opciones lo ON cs.id_ambiente = lo.id
        LEFT JOIN auth_usuarios uc ON cs.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cs.id_usuario_modificacion = um.id
        WHERE cs.estado = 1
          AND (p_id_empresa IS NULL OR cs.id_empresa = p_id_empresa)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(cs.usuario_sol, p_busqueda)
              OR gen_texto_coincide(COALESCE(e.nombre_comercial, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lo.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cs.proveedor_pse, ''), p_busqueda)
          )
        ORDER BY e.nombre_comercial ASC, cs.usuario_sol ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS public.gen_obtener_configuracion_sunat (p_id integer);

CREATE OR REPLACE FUNCTION public.gen_obtener_configuracion_sunat (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            cs.id,
            cs.id_empresa,
            e.nombre_comercial,
            e.ruc AS ruc_empresa,
            cs.usuario_sol,
            cs.clave_sol,
            cs.certificado_digital,
            cs.clave_certificado,
            (cs.clave_sol IS NOT NULL AND TRIM(cs.clave_sol) <> '') AS tiene_clave_sol,
            (cs.clave_certificado IS NOT NULL AND TRIM(cs.clave_certificado) <> '') AS tiene_clave_certificado,
            cs.id_ambiente,
            lo.nombre AS nombre_ambiente,
            cs.proveedor_pse,
            cs.pse_habilitado,
            cs.api_base_url,
            cs.api_token,
            (cs.api_token IS NOT NULL AND TRIM(cs.api_token) <> '') AS tiene_api_token,
            cs.api_usuario,
            cs.api_clave,
            (cs.api_clave IS NOT NULL AND TRIM(cs.api_clave) <> '') AS tiene_api_clave,
            COALESCE(NULLIF(TRIM(cs.ruc_emisor), ''), e.ruc) AS ruc_emisor,
            cs.validez_client_id,
            (NULLIF(TRIM(cs.validez_client_secret), '') IS NOT NULL) AS tiene_validez_client_secret,
            cs.client_id,
            cs.client_secret,
            (cs.client_secret IS NOT NULL AND TRIM(cs.client_secret) <> '') AS tiene_client_secret,
            cs.timeout_ms,
            cs.estado,
            cs.fecha_creacion,
            cs.fecha_modificacion,
            cs.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cs.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_configuracion_sunat cs
        INNER JOIN gen_empresa e ON cs.id_empresa = e.id
        LEFT JOIN gen_lista_opciones lo ON cs.id_ambiente = lo.id
        LEFT JOIN auth_usuarios uc ON cs.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cs.id_usuario_modificacion = um.id
        WHERE cs.id = p_id AND cs.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.inv_revertir_por_documento (
  p_codigo_tipo_documento_origen character varying,
  p_id_documento_origen integer,
  p_id_usuario_auditoria integer,
  p_id_documento_detalle integer
);

DROP FUNCTION IF EXISTS public.inv_revertir_por_documento (
  p_codigo_tipo_documento_origen character varying,
  p_id_documento_origen integer,
  p_id_usuario_auditoria integer,
  p_id_documento_detalle integer,
  p_codigo_tipo_movimiento character varying,
  p_naturaleza character varying
);

CREATE OR REPLACE FUNCTION public.inv_revertir_por_documento (
  p_codigo_tipo_documento_origen character varying,
  p_id_documento_origen integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_id_documento_detalle integer DEFAULT NULL::integer,
  p_codigo_tipo_movimiento character varying DEFAULT NULL::character varying,
  p_naturaleza character varying DEFAULT NULL::character varying
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_id_tipo_mov INTEGER;
    v_naturaleza VARCHAR;
    v_id_estado_en_almacen INTEGER;
    v_mov RECORD;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_almacen_stock INTEGER;
    v_count INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_documento_origen IS NULL THEN
        RETURN json_build_object('revertidos', 0, 'error', 'id_documento_origen es obligatorio');
    END IF;

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, '')))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object(
            'revertidos', 0,
            'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, ''))))
        );
    END IF;

    IF NULLIF(TRIM(COALESCE(p_codigo_tipo_movimiento, '')), '') IS NOT NULL THEN
        SELECT lo.id INTO v_id_tipo_mov
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_mov IS NULL THEN
            RETURN json_build_object(
                'revertidos', 0,
                'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento)))
            );
        END IF;
    END IF;

    v_naturaleza := NULLIF(UPPER(TRIM(COALESCE(p_naturaleza, ''))), '');

    FOR v_mov IN
        SELECT * FROM inv_movimiento
        WHERE estado = 1
          AND id_tipo_documento_origen = v_id_tipo_doc
          AND id_documento_origen = p_id_documento_origen
          AND (p_id_documento_detalle IS NULL OR id_documento_detalle = p_id_documento_detalle)
          AND (v_id_tipo_mov IS NULL OR id_tipo_movimiento = v_id_tipo_mov)
          AND (v_naturaleza IS NULL OR naturaleza = v_naturaleza)
        ORDER BY id DESC
        FOR UPDATE
    LOOP
        SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
        v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
        IF v_es_traslado THEN
            v_es_salida := TRUE;
        ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
            v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
        ELSE
            v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
        END IF;

        IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
            IF v_mov.naturaleza = 'PRODUCTO' THEN
                v_id_almacen_stock := v_mov.id_almacen_origen;
            ELSE
                v_id_almacen_stock := COALESCE(
                    CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino
                );
            END IF;

            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RAISE EXCEPTION
                    'No se encontró el registro de stock para revertir el movimiento %',
                    v_mov.id;
            END IF;

            v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
            IF v_stock_revertido < 0 THEN
                RAISE EXCEPTION
                    'No se puede revertir el movimiento % porque dejaría stock negativo',
                    v_mov.id;
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_actual
                FROM pro_stock
                WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    RAISE EXCEPTION
                        'No se encontró el stock de destino para revertir el traslado %',
                        v_mov.id;
                END IF;

                v_stock_revertido := v_stock_actual - v_mov.cantidad;
                IF v_stock_revertido < 0 THEN
                    RAISE EXCEPTION
                        'No se puede revertir el traslado % porque el destino ya no tiene esa cantidad',
                        v_mov.id;
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END IF;

        IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon
            SET
                id_estado_balon = COALESCE(v_mov.id_estado_balon_anterior, v_id_estado_en_almacen, id_estado_balon),
                id_cliente_ubicacion = CASE
                    WHEN v_mov.id_estado_balon_anterior IS NOT NULL THEN v_mov.id_cliente_ubicacion_anterior
                    ELSE NULL
                END,
                id_almacen = COALESCE(
                    v_mov.id_almacen_anterior,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino,
                    id_almacen
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_mov.id_balon AND estado = 1;
        END IF;

        UPDATE inv_movimiento
        SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_mov.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object('revertidos', v_count);
END;
$function$;

DROP FUNCTION IF EXISTS public.tra_obtener_trabajador (p_id integer);

CREATE OR REPLACE FUNCTION public.tra_obtener_trabajador (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            t.id,
            t.nombres,
            t.apellido_paterno,
            t.apellido_materno,
            t.id_tipo_documento,
            td.nombre  AS nombre_tipo_documento,
    t.numero_documento,
    t.correo,
    t.direccion,
            t.referencia,
            t.latitud,
            t.longitud,
            t.id_pais,
            p.nombre   AS nombre_pais,
            t.id_departamento,
            d.nombre   AS nombre_departamento,
            t.id_provincia,
            pr.nombre  AS nombre_provincia,
            t.id_distrito,
            dis.nombre AS nombre_distrito,
            t.fecha_nacimiento,
            CASE
                WHEN t.fecha_nacimiento IS NULL THEN NULL
                ELSE DATE_PART('year', AGE(CURRENT_DATE, t.fecha_nacimiento))::INT
            END AS edad,
            t.fecha_inicio,
            t.fecha_cese,
            t.id_area,
            a.nombre   AS nombre_area,
            t.id_cargo,
            c.nombre   AS nombre_cargo,
            au.id      AS id_usuario,
            au.nombre  AS nombre_usuario_vinculo,
            (au.id IS NOT NULL) AS es_usuario,
            ch.id      AS id_chofer,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer,
            (ch.id IS NOT NULL) AS es_chofer,
            ch.telefono AS telefono_chofer,
            lic.id AS id_licencia,
            lic.codigo AS codigo_licencia,
            lic.id_tipo_licencia,
            lic.id_categoria_licencia,
            lic.fecha_emision AS fecha_emision_licencia,
            lic.fecha_vencimiento AS fecha_vencimiento_licencia,
            t.estado,
            t.fecha_creacion,
            t.fecha_modificacion,
            t.id_usuario_creacion,
            uc.nombre  AS nombre_usuario_creacion,
            t.id_usuario_modificacion,
            um.nombre  AS nombre_usuario_modificacion
        FROM tra_trabajadores t
        LEFT JOIN gen_lista_opciones td ON t.id_tipo_documento = td.id
        LEFT JOIN gen_pais p            ON t.id_pais = p.id
        LEFT JOIN gen_departamento d    ON t.id_departamento = d.id
        LEFT JOIN gen_provincia pr      ON t.id_provincia = pr.id
        LEFT JOIN gen_distrito dis      ON t.id_distrito = dis.id
        LEFT JOIN gen_lista_opciones a  ON t.id_area = a.id
        LEFT JOIN gen_lista_opciones c  ON t.id_cargo = c.id
        LEFT JOIN auth_usuarios au      ON au.id_trabajador = t.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch         ON ch.id_trabajador = t.id AND ch.estado = 1
        LEFT JOIN LATERAL (
            SELECT gl.* FROM gen_licencia gl
            WHERE gl.id_chofer = ch.id AND gl.estado = 1
            ORDER BY gl.fecha_vencimiento DESC, gl.fecha_emision DESC, gl.id DESC
            LIMIT 1
        ) lic ON TRUE
        LEFT JOIN auth_usuarios uc      ON t.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um      ON t.id_usuario_modificacion = um.id
        WHERE t.id = p_id AND t.estado IN (0, 1)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_pagos json
);

DROP FUNCTION IF EXISTS public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_pagos json,
  p_motivo_correccion character varying,
  p_version_esperada character varying
);

CREATE OR REPLACE FUNCTION public.ven_actualizar_comprobante (
  p_id integer,
  p_fecha date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_detalles json DEFAULT NULL::json,
  p_id_tipo_operacion_sunat integer DEFAULT NULL::integer,
  p_id_comprobante_origen integer DEFAULT NULL::integer,
  p_id_motivo_nota integer DEFAULT NULL::integer,
  p_id_tipo_movimiento integer DEFAULT NULL::integer,
  p_id_tipo_venta integer DEFAULT NULL::integer,
  p_fecha_vencimiento date DEFAULT NULL::date,
  p_tipo_cambio numeric DEFAULT NULL::numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_observaciones character varying DEFAULT NULL::character varying,
  p_periodo_contable character varying DEFAULT NULL::character varying,
  p_operacion character varying DEFAULT NULL::character varying,
  p_id_estado integer DEFAULT NULL::integer,
  p_cuotas json DEFAULT NULL::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_origen_pos character varying DEFAULT NULL::character varying,
  p_pagos json DEFAULT NULL::json,
  p_motivo_correccion character varying DEFAULT NULL::character varying,
  p_version_esperada character varying DEFAULT NULL::character varying
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_err_pagos TEXT;
    v_antes JSONB;
    v_edicion_segura BOOLEAN;
    v_dependencias BOOLEAN;
    v_fisico BOOLEAN;
    v_version TEXT;
    v_estado_sunat VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_sub_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_cuota INTEGER;
    v_numero_cuota INTEGER;
    v_recalcular BOOLEAN := FALSE;
    v_codigo_tipo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_fecha DATE;
    v_id_almacen_actual INTEGER;
    v_id_almacen_nuevo INTEGER;
    v_id_tipo_venta INTEGER;
    v_es_nota_credito BOOLEAN := FALSE;
    v_mueve_stock BOOLEAN := FALSE;
    v_afecta_stock BOOLEAN;
    v_id_tipo_mov_salida INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_qty_antigua NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_id_tipo_mov_aplicar INTEGER;
    v_cantidad_aplicar NUMERIC(12,4);
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';
    PERFORM ven_validar_edicion_pre_emision(p_id);
    SELECT xmin::text INTO v_version FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    v_antes := ven_obtener_comprobante(p_id)::jsonb;

    SELECT
        es.nombre,
        tc.descripcion,
        c.serie,
        c.numero,
        c.fecha,
        c.id_almacen,
        c.id_tipo_venta
    INTO
        v_estado_sunat,
        v_codigo_tipo,
        v_serie,
        v_numero,
        v_fecha,
        v_id_almacen_actual,
        v_id_tipo_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'error', 'No se puede editar un comprobante con estado SUNAT ' || v_estado_sunat,
            'registro', NULL
        );
    END IF;

    IF v_codigo_tipo IN ('NV', 'VSD') AND EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'No se puede editar una venta sin documento que ya fue convertida a boleta/factura',
            'registro',
            NULL
        );
    END IF;

    v_edicion_segura := v_codigo_tipo IN ('NV', 'VSD', '01', '03');
    v_dependencias := EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_comprobante = p_id AND estado = 1 AND (id_balon IS NOT NULL OR COALESCE(descripcion,'') ~* 'garant[ií]a'))
        OR EXISTS (SELECT 1 FROM bal_prestamo WHERE id_comprobante_venta = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM bal_movimiento_recarga WHERE id_comprobante = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM bal_alquiler WHERE id_comprobante_venta = p_id AND estado = 1)
        OR EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON')
        OR EXISTS (SELECT 1 FROM doc_salida WHERE id_venta = p_id AND estado = 1);
    IF v_edicion_segura THEN
        IF p_id_usuario_auditoria IS NULL OR length(btrim(COALESCE(p_motivo_correccion, ''))) < 5 THEN
            RAISE EXCEPTION 'Indique el motivo de la corrección (mínimo 5 caracteres) y el usuario';
        END IF;
        IF p_version_esperada IS NULL OR p_version_esperada <> v_version THEN
            RAISE EXCEPTION 'La venta cambió desde que se abrió. Recargue y revise los datos';
        END IF;
        IF p_id_comprobante_origen IS NOT NULL OR p_id_tipo_venta IS NOT NULL OR p_id_estado IS NOT NULL THEN
            RAISE EXCEPTION 'No se puede cambiar el origen, tipo o estado de una venta mediante corrección';
        END IF;
    END IF;
    v_fisico := p_detalles IS NOT NULL AND (
        (SELECT jsonb_agg(jsonb_build_array(d.item, d.id_producto, d.cantidad, d.id_balon,
                 d.id_unidad_medida, d.capacidad_cilindro, d.id_estado_cilindro,
                 COALESCE(d.descripcion, '')) ORDER BY d.item)
         FROM ven_comprobante_detalle d WHERE d.id_comprobante = p_id AND d.estado = 1)
        IS DISTINCT FROM
        (SELECT jsonb_agg(jsonb_build_array(COALESCE(NULLIF((j.value->>'item')::integer, 0), j.ordinality::integer),
                 (j.value->>'id_producto')::integer, (j.value->>'cantidad')::numeric,
                 NULLIF((j.value->>'id_balon')::integer, 0), NULLIF((j.value->>'id_unidad_medida')::integer, 0),
                 NULLIF((j.value->>'capacidad_cilindro')::numeric, 0), NULLIF((j.value->>'id_estado_cilindro')::integer, 0),
                 COALESCE(j.value->>'descripcion', '')) ORDER BY j.ordinality)
         FROM json_array_elements(p_detalles) WITH ORDINALITY j(value, ordinality))
    );
    IF v_dependencias AND (v_fisico
        OR (p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM (v_antes->'registro'->>'id_cliente')::integer)
        OR (p_id_almacen IS NOT NULL AND p_id_almacen IS DISTINCT FROM v_id_almacen_actual)) THEN
        RAISE EXCEPTION 'La venta tiene balones, préstamos, recargas u órdenes vinculadas. Use Cambio de balón para el movimiento físico; la corrección conserva cliente, almacén y detalle físico';
    END IF;
    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RAISE EXCEPTION 'Debe registrar al menos un detalle';
        END IF;
        PERFORM id FROM pro_producto WHERE id IN (SELECT (value->>'id_producto')::integer FROM json_array_elements(p_detalles)) ORDER BY id FOR SHARE;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) WITH ORDINALITY j(value,ordinality)
            GROUP BY COALESCE(NULLIF((j.value->>'item')::integer,0),j.ordinality::integer) HAVING count(*)>1) THEN
            RAISE EXCEPTION 'Los ítems del detalle no pueden estar duplicados';
        END IF;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            LEFT JOIN pro_producto p ON p.id = (j.value->>'id_producto')::integer AND p.estado = 1
            WHERE p.id IS NULL OR (j.value->>'cantidad')::numeric <= 0
                OR COALESCE((j.value->>'precio_unitario')::numeric, -1) < 0
                OR COALESCE((j.value->>'descuento')::numeric, 0) < 0
                OR COALESCE((j.value->>'porcentaje_igv')::numeric, 18) NOT BETWEEN 0 AND 100
                OR COALESCE((j.value->>'descuento')::numeric, 0) > (j.value->>'cantidad')::numeric * (j.value->>'precio_unitario')::numeric) THEN
            RAISE EXCEPTION 'Detalle inválido: producto inactivo, cantidad, precio o descuento incorrectos';
        END IF;
        IF NOT v_dependencias AND EXISTS (SELECT 1 FROM json_array_elements(p_detalles) j
            WHERE NULLIF((j.value->>'id_balon')::integer, 0) IS NOT NULL
               OR COALESCE((j.value->>'no_mueve_kardex')::boolean, false)) THEN
            RAISE EXCEPTION 'La corrección de productos no puede crear una salida de balón ni omitir el kardex';
        END IF;
        IF EXISTS (SELECT 1 FROM json_array_elements(p_detalles) WITH ORDINALITY j(value,ordinality)
            JOIN ven_comprobante_detalle d ON d.id_comprobante=p_id AND d.estado=1
                AND d.item=COALESCE(NULLIF((j.value->>'item')::integer,0),j.ordinality::integer)
            WHERE COALESCE(d.descripcion,'') ~* 'garant[ií]a' AND
                jsonb_build_array(d.precio_unitario,COALESCE(d.descuento,0),d.porcentaje_igv,d.id_afectacion_igv)
                IS DISTINCT FROM jsonb_build_array((j.value->>'precio_unitario')::numeric,
                    COALESCE((j.value->>'descuento')::numeric,0),COALESCE((j.value->>'porcentaje_igv')::numeric,18),
                    NULLIF((j.value->>'id_afectacion_igv')::integer,0))) THEN
            RAISE EXCEPTION 'Los importes de garantía deben corregirse desde el módulo de garantías';
        END IF;
    END IF;
    IF fin_cuenta_documento_tiene_pagos(p_id,NULL) AND (
        p_cuotas IS NOT NULL OR p_id_condicion_pago IS NOT NULL OR p_id_moneda IS NOT NULL
        OR (p_id_cliente IS NOT NULL AND p_id_cliente IS DISTINCT FROM (v_antes->'registro'->>'id_cliente')::integer)) THEN
        RAISE EXCEPTION 'La cuenta por cobrar tiene pagos; no se pueden reasignar cliente, moneda, condición o cuotas desde la corrección';
    END IF;

    IF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');
    v_mueve_stock := (v_codigo_tipo IN ('01', '03', '07', 'NV', 'VSD'));
    v_id_almacen_nuevo := COALESCE(p_id_almacen, v_id_almacen_actual);
    v_fecha := COALESCE(p_fecha, v_fecha);
    v_id_tipo_venta := COALESCE(p_id_tipo_venta, v_id_tipo_venta);

    IF p_detalles IS NOT NULL THEN
        IF json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
            RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
        END IF;

        v_recalcular := TRUE;

        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

            IF v_id_producto IS NULL OR v_cantidad <= 0 THEN
                RETURN json_build_object('error', 'Detalle inválido: producto y cantidad son obligatorios', 'registro', NULL);
            END IF;

            SELECT
                REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
                COALESCE(p.es_gas, FALSE)
            INTO v_nombre_unidad, v_es_gas
            FROM pro_producto p
            LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
            WHERE p.id = v_id_producto;

            IF NOT COALESCE(v_es_gas, FALSE)
               AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
               AND v_cantidad <> TRUNC(v_cantidad)
            THEN
                RETURN json_build_object(
                    'error',
                    'La cantidad de ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                        || ' debe ser entera (unidad de medida UNID)',
                    'registro',
                    NULL
                );
            END IF;

            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
                IF v_codigo_afectacion = '20' THEN
                    v_exonerado_total := v_exonerado_total + v_valor_linea;
                END IF;
            END IF;

            v_descuento_total := v_descuento_total + v_descuento_linea;
            v_valor_venta_total := v_valor_venta_total + v_valor_linea;
            v_igv_total := v_igv_total + v_impuesto_linea;
            v_sub_total := v_sub_total + v_importe_linea;
            v_total_importe := v_total_importe + v_importe_linea;
        END LOOP;
    END IF;

    IF v_mueve_stock AND (p_detalles IS NOT NULL OR p_id_almacen IS NOT NULL) THEN
        IF EXISTS (
            SELECT 1
            FROM ven_comprobante_detalle d
            INNER JOIN pro_producto p ON p.id = d.id_producto
            WHERE d.id_comprobante = p_id
              AND d.estado = 1
              AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
        ) OR (
            p_detalles IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM json_array_elements(p_detalles) j
                INNER JOIN pro_producto p ON p.id = (j.value->>'id_producto')::INTEGER
                WHERE ven_producto_mueve_kardex_venta(p.id, j.value->>'descripcion')
            )
        ) THEN
            IF v_id_almacen_nuevo IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Debe indicar el almacén para ajustar stock de los productos',
                    'registro',
                    NULL
                );
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_nuevo AND estado = 1
            ) THEN
                RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
            END IF;

            SELECT lo.id INTO v_id_tipo_mov_salida
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            SELECT lo.id INTO v_id_tipo_mov_ingreso
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_salida IS NULL OR v_id_tipo_mov_ingreso IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontraron tipos de movimiento SALIDA/INGRESO',
                    'registro',
                    NULL
                );
            END IF;

            SELECT lo.nombre INTO v_nombre_tipo_venta
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_tipo_venta;

            IF p_detalles IS NULL THEN
                IF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                    FOR v_id_producto, v_qty_antigua IN
                        SELECT d.id_producto, SUM(d.cantidad)
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    LOOP
                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_actual,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_mov_result->>'error';
                        END IF;

                        IF v_es_nota_credito THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                        ELSE
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_qty_antigua THEN
                                RAISE EXCEPTION '%', format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_qty_antigua
                                    );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                        END IF;

                        v_mov_result := inv_registrar_movimiento(
                            'PRODUCTO',
                            CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                            v_fecha,
                            v_id_producto,
                            NULL,
                            v_qty_antigua,
                            v_id_almacen_nuevo,
                            NULL,
                            NULL,
                            ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                            p_id,
                            format('Cambio almacén %s-%s (aplicar)', v_serie, v_numero),
                            p_id_usuario_auditoria,
                            NULL,
                            NULL,
                            TRUE
                        );
                        IF v_mov_result->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_mov_result->>'error';
                        END IF;
                    END LOOP;
                END IF;
            ELSIF v_id_almacen_actual IS DISTINCT FROM v_id_almacen_nuevo THEN
                FOR v_id_producto, v_qty_antigua IN
                    SELECT d.id_producto, SUM(d.cantidad)
                    FROM ven_comprobante_detalle d
                    INNER JOIN pro_producto p ON p.id = d.id_producto
                    WHERE d.id_comprobante = p_id
                      AND d.estado = 1
                      AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                    GROUP BY d.id_producto
                LOOP
                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    ELSE
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_antigua,
                        v_id_almacen_actual,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Cambio almacén %s-%s (revertir)', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;

                FOR v_id_producto, v_qty_nueva IN
                    SELECT
                        (value->>'id_producto')::INTEGER,
                        SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                    FROM json_array_elements(p_detalles)
                    GROUP BY (value->>'id_producto')::INTEGER
                LOOP
                    IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                    ELSE
                        SELECT COALESCE(s.stock, 0)
                        INTO v_stock_disponible
                        FROM pro_stock s
                        WHERE s.id_almacen = v_id_almacen_nuevo
                          AND s.id_producto = v_id_producto
                          AND s.estado = 1;

                        IF COALESCE(v_stock_disponible, 0) < v_qty_nueva THEN
                            RAISE EXCEPTION '%', format(
                                    'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                    COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                    COALESCE(v_stock_disponible, 0),
                                    v_qty_nueva
                                );
                        END IF;
                        v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_qty_nueva,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;
            ELSE
                FOR v_id_producto, v_qty_antigua, v_qty_nueva IN
                    SELECT
                        COALESCE(o.id_producto, n.id_producto),
                        COALESCE(o.cantidad, 0),
                        COALESCE(n.cantidad, 0)
                    FROM (
                        SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                        FROM ven_comprobante_detalle d
                        INNER JOIN pro_producto p ON p.id = d.id_producto
                        WHERE d.id_comprobante = p_id
                          AND d.estado = 1
                          AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                        GROUP BY d.id_producto
                    ) o
                    FULL OUTER JOIN (
                        SELECT
                            (value->>'id_producto')::INTEGER AS id_producto,
                            SUM(COALESCE((value->>'cantidad')::NUMERIC, 0)) AS cantidad
                        FROM json_array_elements(p_detalles)
                        GROUP BY (value->>'id_producto')::INTEGER
                    ) n ON n.id_producto = o.id_producto
                    INNER JOIN pro_producto p ON p.id = COALESCE(o.id_producto, n.id_producto)
                    WHERE ven_producto_mueve_kardex_venta(p.id, NULL)
                LOOP
                    v_delta_stock := v_qty_nueva - v_qty_antigua;
                    IF v_delta_stock = 0 THEN
                        CONTINUE;
                    END IF;

                    IF v_es_nota_credito THEN
                        IF v_delta_stock > 0 THEN
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    ELSE
                        IF v_delta_stock > 0 THEN
                            SELECT COALESCE(s.stock, 0)
                            INTO v_stock_disponible
                            FROM pro_stock s
                            WHERE s.id_almacen = v_id_almacen_nuevo
                              AND s.id_producto = v_id_producto
                              AND s.estado = 1;

                            IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                                RAISE EXCEPTION '%', format(
                                        'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                                        COALESCE(v_stock_disponible, 0),
                                        v_delta_stock
                                    );
                            END IF;
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_salida;
                            v_cantidad_aplicar := v_delta_stock;
                        ELSE
                            v_id_tipo_mov_aplicar := v_id_tipo_mov_ingreso;
                            v_cantidad_aplicar := ABS(v_delta_stock);
                        END IF;
                    END IF;

                    v_mov_result := inv_registrar_movimiento(
                        'PRODUCTO',
                        CASE WHEN v_id_tipo_mov_aplicar = v_id_tipo_mov_salida THEN 'SALIDA' ELSE 'INGRESO' END,
                        v_fecha,
                        v_id_producto,
                        NULL,
                        v_cantidad_aplicar,
                        v_id_almacen_nuevo,
                        NULL,
                        NULL,
                        ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                        p_id,
                        format('Ajuste edición %s-%s', v_serie, v_numero),
                        p_id_usuario_auditoria,
                        NULL,
                        NULL,
                        TRUE
                    );
                    IF v_mov_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_mov_result->>'error';
                    END IF;
                END LOOP;
            END IF;
        END IF;
    END IF;

    UPDATE ven_comprobante
    SET
        fecha = COALESCE(p_fecha, fecha),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_tipo_operacion_sunat = COALESCE(p_id_tipo_operacion_sunat, id_tipo_operacion_sunat),
        id_comprobante_origen = COALESCE(p_id_comprobante_origen, id_comprobante_origen),
        id_motivo_nota = COALESCE(p_id_motivo_nota, id_motivo_nota),
        id_tipo_movimiento = COALESCE(p_id_tipo_movimiento, id_tipo_movimiento),
        id_tipo_venta = COALESCE(p_id_tipo_venta, id_tipo_venta),
        fecha_vencimiento = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        tipo_cambio = COALESCE(p_tipo_cambio, tipo_cambio),
        id_sucursal = COALESCE(p_id_sucursal, id_sucursal),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_condicion_pago = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_moneda = COALESCE(p_id_moneda, id_moneda),
        id_medio_pago = COALESCE(p_id_medio_pago, id_medio_pago),
        sub_total = CASE WHEN v_recalcular THEN v_sub_total ELSE sub_total END,
        descuento = CASE WHEN v_recalcular THEN v_descuento_total ELSE descuento END,
        valor_venta = CASE WHEN v_recalcular THEN v_valor_venta_total ELSE valor_venta END,
        igv = CASE WHEN v_recalcular THEN v_igv_total ELSE igv END,
        total_importe = CASE WHEN v_recalcular THEN v_total_importe ELSE total_importe END,
        exonerado = CASE WHEN v_recalcular THEN v_exonerado_total ELSE exonerado END,
        glosa = COALESCE(p_glosa, glosa),
        observaciones = COALESCE(p_observaciones, observaciones),
        periodo_contable = COALESCE(p_periodo_contable, periodo_contable),
        operacion = COALESCE(p_operacion, operacion),
        origen_pos = COALESCE(NULLIF(TRIM(p_origen_pos), ''), origen_pos),
        id_estado = COALESCE(p_id_estado, id_estado),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_detalles IS NOT NULL THEN
      IF NOT v_dependencias THEN
        UPDATE ven_comprobante_detalle
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

      END IF;
        v_item := 0;
        FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
        LOOP
            v_item := v_item + 1;
            v_id_producto := (v_detalle->>'id_producto')::INTEGER;
            v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
            v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
            v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
            v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
            v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);

            IF v_codigo_afectacion = '10' THEN
                v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
                v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
            ELSE
                v_valor_linea := v_importe_linea;
                v_impuesto_linea := 0;
            END IF;

            IF v_dependencias THEN
                UPDATE ven_comprobante_detalle SET
                    precio_unitario = v_precio_unitario, descuento = v_descuento_linea,
                    valor_venta = v_valor_linea, porcentaje_igv = v_porcentaje_igv,
                    id_afectacion_igv = NULLIF((v_detalle->>'id_afectacion_igv')::integer, 0),
                    impuesto = v_impuesto_linea, importe = v_importe_linea,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = now()
                WHERE id_comprobante = p_id AND estado = 1
                  AND item = COALESCE(NULLIF((v_detalle->>'item')::integer, 0), v_item);
                CONTINUE;
            END IF;
            INSERT INTO ven_comprobante_detalle (
                id_comprobante, item, id_producto, descripcion, id_unidad_medida,
                cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
                id_afectacion_igv, impuesto, importe,
                id_balon, capacidad_cilindro, id_estado_cilindro,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id,
                COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
                v_id_producto,
                NULLIF(v_detalle->>'descripcion', ''),
                NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
                v_cantidad,
                v_precio_unitario,
                v_descuento_linea,
                v_valor_linea,
                v_porcentaje_igv,
                NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0),
                v_impuesto_linea,
                v_importe_linea,
                NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
                NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
                NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_cuota
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;

        UPDATE ven_cuotas
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante = p_id AND estado = 1;

        IF json_typeof(p_cuotas) = 'array' THEN
            FOR v_cuota IN SELECT value FROM json_array_elements(p_cuotas)
            LOOP
                v_numero_cuota := COALESCE((v_cuota->>'numero_cuota')::INTEGER, 0);
                IF v_numero_cuota <= 0 THEN
                    CONTINUE;
                END IF;

                INSERT INTO ven_cuotas (
                    id_comprobante, numero_cuota, fecha_vencimiento, monto,
                    monto_pagado, id_estado,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id,
                    v_numero_cuota,
                    (v_cuota->>'fecha_vencimiento')::DATE,
                    COALESCE((v_cuota->>'monto')::NUMERIC, 0),
                    COALESCE((v_cuota->>'monto_pagado')::NUMERIC, 0),
                    COALESCE(NULLIF((v_cuota->>'id_estado')::INTEGER, 0), v_id_estado_cuota),
                    p_id_usuario_auditoria,
                    p_id_usuario_auditoria
                );
            END LOOP;
        END IF;
    END IF;

    IF NOT v_es_nota_credito THEN
        PERFORM ven_sincronizar_cxc_venta(p_id, p_id_usuario_auditoria);
    END IF;

    v_err_pagos := ven_sincronizar_pagos_comprobante(p_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    IF v_edicion_segura THEN
        INSERT INTO ven_vsd_operacion(id_comprobante, tipo, motivo, datos, anterior, posterior, id_usuario)
        VALUES (p_id, 'CORRECCION', btrim(p_motivo_correccion),
            jsonb_build_object('version', p_version_esperada), v_antes,
            ven_obtener_comprobante(p_id)::jsonb, p_id_usuario_auditoria);
    END IF;
    RETURN ven_obtener_comprobante(p_id);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_cambiar_balon_vsd (p_id integer, p_datos jsonb, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.ven_cambiar_balon_vsd (p_id integer, p_datos jsonb, p_id_usuario integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_venta ven_comprobante%ROWTYPE;
    v_old bal_balon%ROWTYPE;
    v_new bal_balon%ROWTYPE;
    v_pd bal_prestamo_detalle%ROWTYPE;
    v_anterior jsonb;
    v_result json;
    v_existente ven_vsd_operacion%ROWTYPE;
    v_id bigint;
    v_original integer;
    v_old_id integer := (p_datos->>'idBalonActual')::integer;
    v_new_id integer := (p_datos->>'idBalonNuevo')::integer;
    v_almacen integer := (p_datos->>'idAlmacen')::integer;
    v_devuelto numeric := (p_datos->>'cantidadGasDevuelta')::numeric;
    v_salida numeric := (p_datos->>'cantidadGasSalida')::numeric;
    v_condicion text := p_datos->>'condicionDevolucion';
    v_motivo text := btrim(p_datos->>'motivo');
    v_solicitud uuid := (p_datos->>'solicitud')::uuid;
    v_tipo text;
    v_estado text;
    v_producto integer;
    v_prestamo_nuevo integer;
    v_capacidad numeric;
    v_limite numeric;
    v_estado_dest integer;
    v_reserva boolean := p_datos->>'tipoOperacion' = 'CORRECCION_RESERVA';
BEGIN
    SET TIME ZONE 'America/Lima';
    SELECT * INTO v_venta FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'La venta no existe o está anulada'; END IF;
    SELECT * INTO v_existente FROM ven_vsd_operacion WHERE solicitud = v_solicitud;
    IF FOUND THEN
        IF v_existente.id_comprobante <> p_id OR (v_existente.datos - 'idBalonOriginal') <> p_datos OR v_existente.id_usuario <> p_id_usuario THEN
            RAISE EXCEPTION 'La solicitud ya fue utilizada para otra operación';
        END IF;
        RETURN json_build_object('registro', jsonb_build_object('id', v_existente.id, 'repetida', true));
    END IF;
    SELECT descripcion INTO v_tipo FROM gen_lista_opciones WHERE id = v_venta.id_tipo_comprobante;
    IF v_tipo NOT IN ('VSD','NV','01','03') THEN RAISE EXCEPTION 'Seleccione una venta sin documento, factura o boleta'; END IF;
    PERFORM ven_validar_edicion_pre_emision(p_id);
    IF v_solicitud IS NULL OR p_id_usuario IS NULL OR COALESCE(length(v_motivo), 0) < 5 OR length(v_motivo) > 500 THEN
        RAISE EXCEPTION 'Solicitud, usuario y motivo de al menos 5 caracteres son obligatorios';
    END IF;
    IF COALESCE(p_datos->>'tipoOperacion','') NOT IN ('CAMBIO','CORRECCION_RESERVA') THEN RAISE EXCEPTION 'Seleccione corrección de reserva o cambio físico'; END IF;
    IF p_datos->>'versionEsperada' IS DISTINCT FROM (SELECT xmin::text FROM ven_comprobante WHERE id = p_id) THEN
        RAISE EXCEPTION 'La venta cambió. Recargue y revise antes de confirmar';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen = p_id AND estado = 1) THEN
        RAISE EXCEPTION 'La venta ya tiene un documento derivado. Gestione el cambio desde el documento vigente';
    END IF;
    IF EXISTS (SELECT 1 FROM doc_salida d JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE (d.id_venta = p_id OR EXISTS (SELECT 1 FROM doc_salida_referencia r WHERE r.id_doc_salida=d.id AND r.id_comprobante=p_id AND r.estado=1))
          AND d.estado = 1 AND ec.nombre <> 'ANULADA'
          AND (v_reserva OR NOT EXISTS (SELECT 1 FROM age_actividad a
            JOIN gen_lista_opciones ta ON ta.id=a.id_tipo_actividad
            JOIN gen_lista_opciones ea ON ea.id=a.id_estado_actividad
            WHERE a.id_doc_salida=d.id AND a.estado=1 AND ta.nombre='REPARTO' AND ea.nombre='REALIZADA'))) THEN
        RAISE EXCEPTION 'Hay una orden de salida vigente. Finalice o cancele el despacho antes del cambio';
    END IF;
    IF v_old_id IS NULL OR v_new_id IS NULL OR v_old_id = v_new_id OR v_almacen IS NULL
        OR v_devuelto IS NULL OR v_salida IS NULL OR v_devuelto < 0 OR v_salida < 0
        OR v_condicion IS NULL OR v_condicion NOT IN ('DISPONIBLE','EN_MANTENIMIENTO') THEN
        RAISE EXCEPTION 'Indique dos balones distintos, almacén, cantidades no negativas y condición de devolución';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_almacen AND estado = 1) THEN RAISE EXCEPTION 'El almacén está inactivo o no existe'; END IF;
    PERFORM id FROM bal_balon WHERE id IN (v_old_id, v_new_id) ORDER BY id FOR UPDATE;
    SELECT * INTO v_old FROM bal_balon WHERE id = v_old_id AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El balón devuelto no existe o está inactivo'; END IF;
    SELECT * INTO v_new FROM bal_balon WHERE id = v_new_id AND estado = 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'El balón de reemplazo no existe o está inactivo'; END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id = v_old.id_estado_balon;
    IF (v_reserva AND (v_estado IS DISTINCT FROM 'PENDIENTE_ENVIO' OR v_old.id_almacen IS DISTINCT FROM v_venta.id_almacen
            OR v_almacen IS DISTINCT FROM v_venta.id_almacen OR v_old.id_cliente_ubicacion IS NOT NULL))
       OR (NOT v_reserva AND (v_estado NOT IN ('EN_PODER_CLIENTE','PRESTADO_CLIENTE') OR v_old.id_cliente_ubicacion IS DISTINCT FROM v_venta.id_cliente)) THEN
        RAISE EXCEPTION 'El balón devuelto ya no está en poder del cliente de esta venta';
    END IF;
    IF EXISTS (SELECT 1 FROM age_actividad_item i JOIN age_actividad a ON a.id=i.id_actividad
        JOIN gen_lista_opciones ea ON ea.id=a.id_estado_actividad JOIN gen_lista_opciones ta ON ta.id=a.id_tipo_actividad
        WHERE i.id_balon IN (v_old_id,v_new_id) AND i.estado=1 AND a.estado=1 AND ea.nombre NOT IN ('REALIZADA','CANCELADA')
          AND NOT (i.id_balon=v_old_id AND ea.nombre='PENDIENTE' AND ta.nombre='RECOJO'
            AND i.id_prestamo_detalle IN (SELECT pd.id FROM bal_prestamo_detalle pd JOIN bal_prestamo pr ON pr.id=pd.id_prestamo
                 WHERE pr.id_comprobante_venta=p_id AND pr.estado=1 AND pd.estado=1 AND pd.fecha_devolucion IS NULL AND pd.rol='ENTREGADO'))) THEN
        RAISE EXCEPTION 'Un balón tiene una actividad pendiente o en ruta incompatible con el cambio';
    END IF;
    SELECT (datos->>'idBalonOriginal')::integer INTO v_original FROM ven_vsd_operacion
        WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON'
          AND (datos->>'idBalonNuevo')::integer = v_old_id ORDER BY id DESC LIMIT 1;
    v_original := COALESCE(v_original, v_old_id);
    IF NOT EXISTS (SELECT 1 FROM ven_comprobante_detalle WHERE id_comprobante = p_id AND estado = 1 AND id_balon IN (v_original,v_old_id))
       AND NOT EXISTS (SELECT 1 FROM bal_prestamo_detalle pd JOIN bal_prestamo pr ON pr.id = pd.id_prestamo
          WHERE pr.id_comprobante_venta = p_id AND pr.estado = 1 AND pd.estado = 1 AND pd.id_balon = v_old_id
            AND pd.fecha_devolucion IS NULL AND pd.rol = 'ENTREGADO') THEN
        RAISE EXCEPTION 'El balón no pertenece a esta venta o ya fue devuelto';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante = p_id AND tipo = 'CAMBIO_BALON'
        AND (datos->>'idBalonActual')::integer = v_old_id
        AND id > COALESCE((SELECT max(id) FROM ven_vsd_operacion WHERE id_comprobante = p_id
             AND tipo = 'CAMBIO_BALON' AND (datos->>'idBalonNuevo')::integer = v_old_id), 0)) THEN
        RAISE EXCEPTION 'Este balón ya fue sustituido; recargue la venta';
    END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id = v_new.id_estado_balon;
    IF v_estado IS DISTINCT FROM 'DISPONIBLE' OR v_new.id_almacen IS DISTINCT FROM v_almacen OR v_new.id_cliente_ubicacion IS NOT NULL THEN
        RAISE EXCEPTION 'El balón de reemplazo ya no está disponible en el almacén seleccionado';
    END IF;
    IF v_new.fecha_proxima_prueba_hidrostatica IS NULL OR v_new.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN
        RAISE EXCEPTION 'El balón de reemplazo no tiene una prueba hidrostática vigente';
    END IF;
    IF EXISTS (SELECT 1 FROM bal_baja_balon WHERE id_balon=v_new_id AND estado=1 AND estado_aprobacion IN ('PENDIENTE','APROBADA'))
        OR EXISTS (SELECT 1 FROM bal_mantenimiento m WHERE m.id_balon=v_new_id AND m.estado=1 AND m.fecha_salida IS NULL) THEN
        RAISE EXCEPTION 'El balón de reemplazo tiene una baja o mantenimiento pendiente';
    END IF;
    IF v_condicion='DISPONIBLE' AND EXISTS (SELECT 1 FROM bal_baja_balon WHERE id_balon=v_old_id AND estado=1 AND estado_aprobacion IN ('PENDIENTE','APROBADA')) THEN
        RAISE EXCEPTION 'El balón devuelto tiene una solicitud de baja; no puede quedar disponible';
    END IF;
    IF v_new.id_tipo_balon IS DISTINCT FROM v_old.id_tipo_balon
       OR v_new.id_producto_gas IS DISTINCT FROM v_old.id_producto_gas
       OR v_new.id_propietario IS DISTINCT FROM v_old.id_propietario
       OR v_new.id_cliente_propietario IS DISTINCT FROM v_old.id_cliente_propietario THEN
        RAISE EXCEPTION 'El reemplazo debe tener el mismo gas, tipo y propietario. Un cambio comercial requiere devolución y una nueva venta';
    END IF;
    IF EXISTS (SELECT 1 FROM bal_prestamo_detalle pd JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1
        WHERE pd.id_balon = v_new_id AND pd.estado = 1 AND pd.fecha_devolucion IS NULL) THEN
        RAISE EXCEPTION 'El balón de reemplazo ya tiene un préstamo activo';
    END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante_detalle d JOIN ven_comprobante c ON c.id = d.id_comprobante AND c.estado = 1
        WHERE d.id_balon = v_new_id AND d.estado = 1
          AND NOT EXISTS (SELECT 1 FROM ven_vsd_operacion o WHERE o.id_comprobante = c.id AND o.tipo = 'CAMBIO_BALON'
            AND (o.datos->>'idBalonActual')::integer = v_new_id)) THEN
        RAISE EXCEPTION 'El reemplazo está vinculado a otra línea o venta; revise su disponibilidad';
    END IF;
    v_producto := v_old.id_producto_gas;
    PERFORM id FROM pro_producto WHERE id=v_producto FOR SHARE;
    v_capacidad := bal_capacidad_balon_en_unidad_gas(v_old_id);
    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = v_producto AND estado = 1 AND es_gas) THEN
        RAISE EXCEPTION 'El gas está inactivo o no existe';
    END IF;
    v_limite := ven_cantidad_gas_balon_vsd(p_id,v_old_id,v_original);
    IF v_reserva AND (v_salida <> 0 OR v_devuelto <> 0 OR v_condicion <> 'DISPONIBLE') THEN
        RAISE EXCEPTION 'Corregir una reserva no mueve gas y devuelve el balón anterior a disponible';
    END IF;
    IF NOT v_reserva AND (COALESCE(v_capacidad, 0) <= 0 OR COALESCE(v_limite, 0) <= 0
        OR v_salida <> LEAST(v_capacidad, v_limite) OR v_devuelto > v_salida) THEN
        RAISE EXCEPTION 'La cantidad de salida debe coincidir con lo vendido y la capacidad del balón; el remanente no puede superarla';
    END IF;
    SELECT pd.* INTO v_pd FROM bal_prestamo_detalle pd
        JOIN LATERAL (SELECT id FROM bal_prestamo pr WHERE pr.id = pd.id_prestamo AND pr.id_comprobante_venta = p_id AND pr.estado = 1) pr ON true
        WHERE pd.id_balon = v_old_id AND pd.estado = 1 AND pd.fecha_devolucion IS NULL AND pd.rol = 'ENTREGADO'
        FOR UPDATE OF pd;
    IF v_old.id_estado_balon = (SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista
        WHERE l.nombre='EstadoBalon' AND lo.nombre='PRESTADO_CLIENTE' LIMIT 1) AND v_pd.id IS NULL THEN
        RAISE EXCEPTION 'El préstamo del balón no pertenece a esta venta';
    END IF;
    IF v_reserva AND v_pd.id IS NOT NULL THEN RAISE EXCEPTION 'La reserva ya tiene préstamo; utilice su flujo de devolución'; END IF;
    SELECT lo.id INTO v_estado_dest FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista
        WHERE l.nombre='EstadoBalon' AND lo.nombre=v_condicion AND lo.estado=1 LIMIT 1;
    IF v_estado_dest IS NULL THEN RAISE EXCEPTION 'La condición de devolución no está configurada'; END IF;
    IF NOT v_reserva AND v_condicion='DISPONIBLE' AND (v_old.fecha_proxima_prueba_hidrostatica IS NULL OR v_old.fecha_proxima_prueba_hidrostatica<CURRENT_DATE) THEN
        RAISE EXCEPTION 'El balón devuelto no tiene PH vigente; regístrelo para mantenimiento';
    END IF;
    v_anterior := jsonb_build_object('venta', to_jsonb(v_venta), 'balonActual', to_jsonb(v_old), 'balonNuevo', to_jsonb(v_new), 'prestamoDetalle', to_jsonb(v_pd),
        'detallesVenta',(SELECT jsonb_agg(to_jsonb(d) ORDER BY d.id) FROM ven_comprobante_detalle d WHERE id_comprobante=p_id AND estado=1),
        'garantias',(SELECT jsonb_agg(to_jsonb(g) ORDER BY g.id) FROM ven_garantia g WHERE id_prestamo_detalle=v_pd.id AND estado=1),
        'actividades',(SELECT jsonb_agg(to_jsonb(i) ORDER BY i.id) FROM age_actividad_item i WHERE id_prestamo_detalle=v_pd.id AND estado=1));
    INSERT INTO ven_vsd_operacion(id_comprobante, tipo, solicitud, motivo, datos, anterior, posterior, id_usuario)
        VALUES (p_id, 'CAMBIO_BALON', v_solicitud, v_motivo, p_datos, v_anterior, '{}'::jsonb, p_id_usuario) RETURNING id INTO v_id;
    v_result := inv_registrar_movimiento(p_naturaleza=>'BALON', p_codigo_tipo_movimiento=>'ENTRADA_DEVOLUCION',
        p_id_balon=>v_old_id, p_id_almacen_destino=>v_almacen, p_id_cliente=>v_venta.id_cliente,
        p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
        p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
    PERFORM ven_raise_si_error(v_result);
    IF v_condicion = 'EN_MANTENIMIENTO' AND v_devuelto <> 0 THEN RAISE EXCEPTION 'Un balón para mantenimiento no puede reponer gas utilizable'; END IF;
    IF v_devuelto > 0 THEN
        v_result := inv_registrar_movimiento(p_naturaleza=>'PRODUCTO', p_codigo_tipo_movimiento=>'INGRESO',
            p_id_producto=>v_producto, p_cantidad=>v_devuelto, p_id_almacen_origen=>v_almacen,
            p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
            p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END IF;
    v_result := inv_registrar_movimiento(p_naturaleza=>'BALON',
        p_codigo_tipo_movimiento=>CASE WHEN v_pd.id IS NULL THEN 'SALIDA_VENTA' ELSE 'SALIDA_PRESTAMO' END,
        p_id_balon=>v_new_id, p_id_producto=>v_producto, p_cantidad=>v_salida,
        p_id_almacen_origen=>v_almacen, p_id_cliente=>v_venta.id_cliente,
        p_codigo_tipo_documento_origen=>'CAMBIO_VSD', p_id_documento_origen=>v_id::integer,
        p_glosa=>v_motivo, p_id_usuario_auditoria=>p_id_usuario);
    PERFORM ven_raise_si_error(v_result);
    UPDATE bal_balon SET id_estado_balon=v_estado_dest, id_usuario_modificacion=p_id_usuario, fecha_modificacion=now() WHERE id=v_old_id;
    IF v_reserva THEN
        UPDATE bal_balon SET id_estado_balon=v_old.id_estado_balon,id_almacen=v_almacen,id_cliente_ubicacion=NULL,
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now() WHERE id=v_new_id;
        UPDATE ven_comprobante_detalle SET id_balon=v_new_id,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_comprobante=p_id AND id_balon=v_old_id AND estado=1;
    END IF;
    IF NOT v_reserva AND v_tipo IN ('01','03') THEN
        UPDATE ven_comprobante_detalle SET id_balon=v_new_id,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_comprobante=p_id AND id_balon=v_old_id AND estado=1;
    END IF;
    IF v_pd.id IS NOT NULL THEN
        UPDATE bal_prestamo_detalle SET fecha_devolucion=CURRENT_DATE,
            id_estado=(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoPrestamoDetalle' AND lo.nombre='DEVUELTO' LIMIT 1),
            id_usuario_modificacion=p_id_usuario, fecha_modificacion=now() WHERE id=v_pd.id;
        INSERT INTO bal_prestamo_detalle(id_prestamo,id_balon,id_producto,motivo_especifico,fecha_entregado,fecha_prestamo,dias_prestamo,fecha_vencimiento,id_estado,observacion,rol,id_usuario_creacion,id_usuario_modificacion)
        VALUES (v_pd.id_prestamo,v_new_id,v_producto,v_pd.motivo_especifico,CURRENT_DATE,v_pd.fecha_prestamo,v_pd.dias_prestamo,v_pd.fecha_vencimiento,v_pd.id_estado,v_motivo,'ENTREGADO',p_id_usuario,p_id_usuario)
        RETURNING id INTO v_prestamo_nuevo;
        UPDATE ven_garantia SET id_prestamo_detalle=v_prestamo_nuevo,id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            WHERE id_prestamo_detalle=v_pd.id AND estado=1;
        UPDATE age_actividad_item i SET id_balon=v_new_id,id_prestamo_detalle=v_prestamo_nuevo,
            id_usuario_modificacion=p_id_usuario,fecha_modificacion=now()
            FROM age_actividad a, gen_lista_opciones ea, gen_lista_opciones ta
            WHERE i.id_actividad=a.id AND a.id_estado_actividad=ea.id AND a.id_tipo_actividad=ta.id
              AND i.id_prestamo_detalle=v_pd.id AND i.estado=1 AND a.estado=1 AND ea.nombre='PENDIENTE' AND ta.nombre='RECOJO';
    END IF;
    UPDATE ven_vsd_operacion SET datos=datos || jsonb_build_object('idBalonOriginal',v_original),
        posterior=jsonb_build_object('balonDevuelto',(SELECT to_jsonb(b) FROM bal_balon b WHERE id=v_old_id),
             'balonEntregado',(SELECT to_jsonb(b) FROM bal_balon b WHERE id=v_new_id), 'idPrestamoDetalleNuevo',v_prestamo_nuevo)
        WHERE id=v_id;
    UPDATE ven_comprobante SET fecha_modificacion=now(),id_usuario_modificacion=p_id_usuario WHERE id=p_id;
    RETURN json_build_object('registro', jsonb_build_object('id',v_id,'repetida',false));
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_cantidad_gas_balon_vsd (p_id integer, p_balon integer, p_original integer);

CREATE OR REPLACE FUNCTION public.ven_cantidad_gas_balon_vsd (
  p_id integer,
  p_balon integer,
  p_original integer DEFAULT NULL::integer
) RETURNS numeric LANGUAGE plpgsql STABLE AS $function$
DECLARE v_original integer := p_original; v_producto integer; v_capacidad numeric; v_qty numeric; v_count integer;
BEGIN
    SELECT id_producto_gas,bal_capacidad_balon_en_unidad_gas(id) INTO v_producto,v_capacidad FROM bal_balon WHERE id=p_balon AND estado=1;
    IF v_original IS NULL THEN
        SELECT (datos->>'idBalonOriginal')::integer INTO v_original FROM ven_vsd_operacion
            WHERE id_comprobante=p_id AND tipo='CAMBIO_BALON' AND (datos->>'idBalonNuevo')::integer=p_balon ORDER BY id DESC LIMIT 1;
    END IF;
    v_original := COALESCE(v_original,p_balon);
    SELECT sum(cantidad) INTO v_qty FROM ven_comprobante_detalle
        WHERE id_comprobante=p_id AND estado=1 AND id_producto=v_producto AND id_balon IN (p_balon,v_original);
    IF v_qty IS NULL THEN
        SELECT count(*),max(cantidad) INTO v_count,v_qty FROM ven_comprobante_detalle
            WHERE id_comprobante=p_id AND estado=1 AND id_producto=v_producto;
        IF v_count <> 1 THEN RETURN NULL; END IF;
    END IF;
    IF COALESCE(v_capacidad,0)<=0 OR COALESCE(v_qty,0)<=0 OR v_qty>v_capacidad THEN RETURN NULL; END IF;
    RETURN v_qty;
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_comprobante_permite_edicion (c ven_comprobante);

CREATE OR REPLACE FUNCTION public.ven_comprobante_permite_edicion (c ven_comprobante) RETURNS boolean LANGUAGE plpgsql STABLE AS $function$
DECLARE v_tipo text; v_estado text; v_payload jsonb; v_respuesta jsonb; v_codigo text; v_rechazo boolean:=false;
BEGIN
    IF c.estado<>1 THEN RETURN false; END IF;
    SELECT descripcion INTO v_tipo FROM gen_lista_opciones WHERE id=c.id_tipo_comprobante;
    IF v_tipo IN ('VSD','NV') THEN
        RETURN NOT EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen=c.id AND estado=1);
    END IF;
    IF v_tipo NOT IN ('01','03') THEN RETURN false; END IF;
    SELECT nombre INTO v_estado FROM gen_lista_opciones WHERE id=c.id_estado_sunat;
    IF COALESCE(v_estado,'') NOT IN ('PENDIENTE','RECHAZADO') OR ven_cpe_validez_aceptada(c) THEN RETURN false; END IF;
    IF position('emision_por_confirmar' IN COALESCE(c.cdr_respuesta,''))>0 THEN RETURN false; END IF;
    IF v_estado='PENDIENTE' AND (
        NULLIF(btrim(c.ticket_sunat),'') IS NOT NULL
        OR c.hash_documento IS NOT NULL OR c.xml_firmado IS NOT NULL OR c.cdr_respuesta IS NOT NULL
    ) THEN RETURN false; END IF;
    IF v_estado='RECHAZADO' THEN
        IF NULLIF(btrim(c.cdr_respuesta),'') IS NULL OR NULLIF(btrim(c.ticket_sunat),'') IS NOT NULL THEN RETURN false; END IF;
        BEGIN v_payload:=c.cdr_respuesta::jsonb;
        EXCEPTION WHEN invalid_text_representation THEN RETURN false;
        END;
        v_respuesta:=COALESCE(v_payload->'sunatResponse',v_payload);
        v_codigo:=NULLIF(btrim(v_respuesta#>>'{cdrResponse,code}'),'');
        IF v_codigo IS NOT NULL THEN
            IF v_codigo !~ '^[0-9]{1,8}$' THEN RETURN false; END IF;
            v_rechazo:=v_codigo::numeric=99 OR v_codigo::numeric BETWEEN 2000 AND 3999;
        ELSIF v_respuesta#>'{cdrResponse,accepted}'='false'::jsonb THEN
            v_rechazo:=true;
        ELSIF v_respuesta#>'{cdrResponse,accepted}'='true'::jsonb THEN
            RETURN false;
        ELSE
            v_codigo:=NULLIF(btrim(v_respuesta#>>'{error,code}'),'');
            IF v_codigo IS NOT NULL AND v_codigo ~ '^[0-9]{1,8}$' THEN
                v_rechazo:=v_codigo::numeric BETWEEN 2000 AND 3999;
            END IF;
        END IF;
        IF NOT v_rechazo THEN RETURN false; END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM ven_resumen_diario_detalle rd
        JOIN ven_resumen_diario r ON r.id=rd.id_resumen AND r.estado=1
        LEFT JOIN gen_lista_opciones er ON er.id=r.id_estado_sunat
        WHERE rd.id_comprobante=c.id AND rd.estado=1 AND COALESCE(er.nombre,'')<>'RECHAZADO') THEN RETURN false; END IF;
    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen=c.id AND estado=1) THEN RETURN false; END IF;
    RETURN true;
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_convertir_tipo_comprobante (
  p_id integer,
  p_codigo_tipo_destino character varying,
  p_serie character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.ven_convertir_tipo_comprobante (
  p_id integer,
  p_codigo_tipo_destino character varying,
  p_serie character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_doc RECORD;
    v_destino VARCHAR;
    v_id_tipo_destino INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_label_anterior VARCHAR;
    v_label_nuevo VARCHAR;
    v_ref_anterior VARCHAR;
    v_ref_nuevo VARCHAR;
    v_id_ref_anterior INTEGER;
    v_id_ref_nuevo INTEGER;
    v_id_pendiente INTEGER;
    v_tiene_envio BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT pg_try_advisory_xact_lock(872016, p_id) THEN
        RETURN json_build_object('error', 'Hay una emisión a SUNAT en curso para este comprobante; espera a que termine.', 'registro', NULL);
    END IF;

    SELECT c.*, tc.descripcion AS codigo_tipo, es.nombre AS estado_sunat,
           COALESCE(tv.nombre, 'VENTA') AS nombre_tipo_venta,
           cli.numero_documento AS documento_cliente
    INTO v_doc
    FROM ven_comprobante c
    JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
    LEFT JOIN gen_lista_opciones tv ON tv.id = c.id_tipo_venta
    LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
    WHERE c.id = p_id AND c.estado = 1
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    v_destino := TRIM(COALESCE(p_codigo_tipo_destino, ''));

    IF v_doc.codigo_tipo NOT IN ('01', '03') THEN
        RETURN json_build_object('error', 'Solo se puede convertir una boleta o una factura', 'registro', NULL);
    END IF;
    IF v_destino NOT IN ('01', '03') THEN
        RETURN json_build_object('error', 'El tipo destino debe ser 01 (factura) o 03 (boleta)', 'registro', NULL);
    END IF;
    IF v_destino = v_doc.codigo_tipo THEN
        RETURN json_build_object('error', 'El comprobante ya es de ese tipo', 'registro', NULL);
    END IF;

    IF v_doc.estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'error', 'El comprobante ya está ' || v_doc.estado_sunat || ' en SUNAT: no se puede cambiar de tipo. Emite una nota de crédito y un comprobante nuevo.',
            'registro', NULL
        );
    END IF;

    v_tiene_envio := NULLIF(TRIM(COALESCE(v_doc.ticket_sunat, '')), '') IS NOT NULL
        OR v_doc.hash_documento IS NOT NULL
        OR v_doc.xml_firmado IS NOT NULL
        OR v_doc.cdr_respuesta IS NOT NULL;

    IF v_tiene_envio AND COALESCE(v_doc.estado_sunat, '') <> 'RECHAZADO' THEN
        RETURN json_build_object(
            'error', 'El comprobante ya se intentó enviar a SUNAT y su resultado no está confirmado. Consulta su estado antes de cambiarlo de tipo.',
            'registro', NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_resumen_diario_detalle rd
        JOIN ven_resumen_diario r ON r.id = rd.id_resumen AND r.estado = 1
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado_sunat
        WHERE rd.id_comprobante = p_id AND rd.estado = 1
          AND COALESCE(er.nombre, '') <> 'RECHAZADO'
    ) THEN
        RETURN json_build_object('error', 'La boleta está incluida en un resumen diario enviado a SUNAT: no se puede cambiar de tipo.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El comprobante tiene notas u otros documentos derivados: no se puede cambiar de tipo.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_percepcion_detalle WHERE id_comprobante = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El comprobante figura en un comprobante de percepción: no se puede cambiar de tipo.', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        WHERE d.estado = 1
          AND (d.id_venta = p_id OR EXISTS (
                SELECT 1 FROM doc_salida_referencia r
                WHERE r.id_doc_salida = d.id AND r.id_comprobante = p_id AND r.estado = 1))
          AND (d.emitido_sunat
               OR NULLIF(TRIM(COALESCE(d.ticket_sunat, '')), '') IS NOT NULL
               OR EXISTS (SELECT 1 FROM doc_gre_intento i WHERE i.id_doc_salida = d.id AND i.estado <> 'RECHAZADO'))
    ) THEN
        RETURN json_build_object(
            'error', 'La guía de remisión de esta venta ya se envió a SUNAT citando su número actual: no se puede cambiar de tipo.',
            'registro', NULL
        );
    END IF;

    IF v_destino = '01' AND COALESCE(TRIM(v_doc.documento_cliente), '') !~ '^[0-9]{11}$' THEN
        RETURN json_build_object('error', 'La factura requiere un cliente con RUC (11 dígitos). Cambia el cliente antes de convertir.', 'registro', NULL);
    END IF;

    v_serie := UPPER(TRIM(COALESCE(p_serie, '')));
    IF v_serie = '' THEN
        v_serie := CASE WHEN v_destino = '01' THEN 'F002' ELSE 'B002' END;
    END IF;

    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object('error', 'La serie electrónica debe tener 4 caracteres (ej. F001, B001)', 'registro', NULL);
    END IF;
    IF v_destino = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;
    IF v_destino = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_destino
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoComprobante' AND lo.descripcion = v_destino AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_destino IS NULL THEN
        RETURN json_build_object('error', format('Tipo de comprobante %s no configurado', v_destino), 'registro', NULL);
    END IF;

    v_numero := ven_obtener_siguiente_numero(v_id_tipo_destino, v_serie)->>'numero';
    IF v_numero IS NULL OR TRIM(v_numero) = '' THEN
        RETURN json_build_object('error', 'No se pudo asignar el correlativo de la serie ' || v_serie, 'registro', NULL);
    END IF;

    v_label_anterior := v_doc.serie || '-' || v_doc.numero;
    v_label_nuevo := v_serie || '-' || v_numero;

    v_ref_anterior := ven_resolver_tipo_documento_ref(v_doc.codigo_tipo, v_doc.nombre_tipo_venta);
    v_ref_nuevo := ven_resolver_tipo_documento_ref(v_destino, v_doc.nombre_tipo_venta);

    IF v_ref_anterior <> v_ref_nuevo THEN
        SELECT lo.id INTO v_id_ref_anterior
        FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = v_ref_anterior AND lo.estado = 1
        LIMIT 1;
        SELECT lo.id INTO v_id_ref_nuevo
        FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = v_ref_nuevo AND lo.estado = 1
        LIMIT 1;

        IF v_id_ref_anterior IS NULL OR v_id_ref_nuevo IS NULL THEN
            RAISE EXCEPTION 'Tipo de documento de inventario % o % no configurado', v_ref_anterior, v_ref_nuevo;
        END IF;

        UPDATE inv_movimiento
        SET id_tipo_documento_origen = v_id_ref_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_documento_origen = p_id
          AND id_tipo_documento_origen = v_id_ref_anterior;
    END IF;

    UPDATE doc_salida_referencia
    SET id_tipo_comprobante = v_id_tipo_destino,
        serie = v_serie,
        numero = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE doc_salida
    SET observaciones = replace(observaciones, v_label_anterior, v_label_nuevo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_venta = p_id AND estado = 1
      AND observaciones LIKE '%' || v_label_anterior || '%';

    UPDATE fin_cuenta
    SET numero_comprobante = CASE WHEN numero_comprobante IS NULL THEN NULL ELSE v_label_nuevo END,
        descripcion = replace(descripcion, v_label_anterior, v_label_nuevo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_venta = p_id;

    UPDATE bal_baja_balon
    SET serie_comprobante = v_serie,
        numero_comprobante = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_venta = p_id;

    UPDATE bal_movimiento_recarga
    SET serie_factura = v_serie,
        numero_factura = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND serie_factura IS NOT NULL;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    UPDATE ven_comprobante
    SET id_tipo_comprobante = v_id_tipo_destino,
        serie = v_serie,
        numero = v_numero,
        id_estado_sunat = COALESCE(v_id_pendiente, id_estado_sunat),
        ticket_sunat = NULL,
        hash_documento = NULL,
        xml_firmado = NULL,
        cdr_respuesta = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object(
        'registro', json_build_object(
            'id', p_id,
            'codigo_tipo_comprobante', v_destino,
            'serie', v_serie,
            'numero', v_numero,
            'serie_anterior', v_doc.serie,
            'numero_anterior', v_doc.numero
        )
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_crear_comprobante (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_cliente integer,
  p_detalles json,
  p_id_tipo_operacion_sunat integer,
  p_id_comprobante_origen integer,
  p_id_motivo_nota integer,
  p_id_tipo_movimiento integer,
  p_id_tipo_venta integer,
  p_fecha_vencimiento date,
  p_tipo_cambio numeric,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_condicion_pago integer,
  p_id_moneda integer,
  p_id_medio_pago integer,
  p_glosa character varying,
  p_observaciones character varying,
  p_periodo_contable character varying,
  p_operacion character varying,
  p_id_estado integer,
  p_cuotas json,
  p_id_usuario_auditoria integer,
  p_origen_pos character varying,
  p_efectos_pos json,
  p_pagos json
);

CREATE OR REPLACE FUNCTION public.ven_crear_comprobante (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying DEFAULT NULL::character varying,
  p_fecha date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_detalles json DEFAULT '[]'::json,
  p_id_tipo_operacion_sunat integer DEFAULT NULL::integer,
  p_id_comprobante_origen integer DEFAULT NULL::integer,
  p_id_motivo_nota integer DEFAULT NULL::integer,
  p_id_tipo_movimiento integer DEFAULT NULL::integer,
  p_id_tipo_venta integer DEFAULT NULL::integer,
  p_fecha_vencimiento date DEFAULT NULL::date,
  p_tipo_cambio numeric DEFAULT 3.5,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_observaciones character varying DEFAULT NULL::character varying,
  p_periodo_contable character varying DEFAULT NULL::character varying,
  p_operacion character varying DEFAULT NULL::character varying,
  p_id_estado integer DEFAULT NULL::integer,
  p_cuotas json DEFAULT NULL::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_origen_pos character varying DEFAULT NULL::character varying,
  p_efectos_pos json DEFAULT NULL::json,
  p_pagos json DEFAULT NULL::json
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_err_pagos TEXT;
    v_id INTEGER;
    v_id_detalle INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_detalle JSON;
    v_cuota JSON;
    v_item INTEGER;
    v_items_sin_kardex INTEGER[];
    v_id_producto INTEGER;
    v_cantidad NUMERIC(12,4);
    v_precio_unitario NUMERIC(12,6);
    v_descuento_linea NUMERIC(12,4);
    v_porcentaje_igv NUMERIC(6,4);
    v_valor_linea NUMERIC(12,4);
    v_impuesto_linea NUMERIC(12,4);
    v_importe_linea NUMERIC(12,4);
    v_codigo_afectacion VARCHAR;
    v_sub_total NUMERIC(12,4) := 0;
    v_descuento_total NUMERIC(12,4) := 0;
    v_valor_venta_total NUMERIC(12,4) := 0;
    v_igv_total NUMERIC(12,4) := 0;
    v_total_importe NUMERIC(12,4) := 0;
    v_exonerado_total NUMERIC(12,4) := 0;
    v_id_estado_sunat INTEGER;
    v_id_estado_doc INTEGER;
    v_codigo_tipo VARCHAR;
    v_numero_cuota INTEGER;
    v_id_estado_cuota INTEGER;
    v_serie_origen VARCHAR;
    v_familia_origen CHAR(1);
    v_afecta_stock BOOLEAN;
    v_requiere_stock BOOLEAN := FALSE;
    v_es_conversion_vsd BOOLEAN := FALSE;
    v_es_nota_credito BOOLEAN := FALSE;
    v_codigo_tipo_origen VARCHAR;
    v_id_almacen_origen INTEGER;
    v_id_tipo_mov_inv INTEGER;
    v_id_tipo_mov_ingreso INTEGER;
    v_nombre_tipo_venta VARCHAR;
    v_stock_disponible NUMERIC(12,4);
    v_mov_result JSON;
    v_glosa_mov VARCHAR;
    v_qty_origen NUMERIC(12,4);
    v_qty_nc_previas NUMERIC(12,4);
    v_qty_nueva NUMERIC(12,4);
    v_delta_stock NUMERIC(12,4);
    v_estado_sunat_origen VARCHAR;
    v_id_afectacion_igv INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
    v_es_servicio BOOLEAN;
    v_err_caja TEXT;
    v_dias_credito INTEGER := 0;
    v_numero_cuotas INTEGER := 0;
    v_dia_mes_pago INTEGER;
    v_fecha_venc_cxc DATE;
    v_fecha_primera_cuota DATE;
    v_id_tipo_cobrar INTEGER;
    v_cxc_result JSON;
    v_mes_base DATE;
    v_ultimo_dia_mes DATE;
    v_total_origen NUMERIC(12,4);
    v_id_balon INTEGER;
    v_nombre_estado_balon VARCHAR;
    v_id_estado_pendiente_envio INTEGER;
    v_id_estado_disponible INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante_origen IS NOT NULL THEN
        PERFORM 1 FROM ven_comprobante WHERE id=p_id_comprobante_origen FOR UPDATE;
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND EXISTS (
        SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante=p_id_comprobante_origen AND tipo='CAMBIO_BALON' AND datos->>'tipoOperacion'='CAMBIO'
    ) THEN
        RAISE EXCEPTION 'La venta tiene cambios físicos registrados. Debe conciliarse antes de generar un documento derivado';
    END IF;

    v_serie := UPPER(TRIM(p_serie));

    IF p_id_tipo_comprobante IS NULL THEN
        RETURN json_build_object('error', 'El tipo de comprobante es obligatorio', 'registro', NULL);
    END IF;

    IF v_serie IS NULL OR v_serie = '' THEN
        RETURN json_build_object('error', 'La serie es obligatoria', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del comprobante es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_sucursal IS NULL AND p_id_almacen IS NOT NULL THEN
        SELECT a.id_sucursal INTO p_id_sucursal
        FROM gen_almacen a
        WHERE a.id = p_id_almacen
          AND a.estado = 1
        LIMIT 1;
    END IF;

    v_err_caja := fin_caja_assert_abierta(p_fecha, p_id_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un detalle', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT lo.descripcion INTO v_codigo_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_comprobante;

    IF v_codigo_tipo IN ('NV', 'VSD') THEN
        IF NOT (
            (char_length(v_serie) = 5 AND left(v_serie, 3) = 'VSD')
            OR (char_length(v_serie) = 4 AND left(v_serie, 2) = 'NV')
        ) THEN
            RETURN json_build_object(
                'error',
                'La venta sin documento debe usar serie VSD## (ej. VSD01)',
                'registro',
                NULL
            );
        END IF;
    ELSIF char_length(v_serie) <> 4 THEN
        RETURN json_build_object(
            'error',
            'La serie electrónica debe tener 4 caracteres (ej. F001, B001, FC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND left(v_serie, 1) NOT IN ('F', 'B') THEN
        RETURN json_build_object(
            'error',
            'La nota de crédito/débito debe usar serie que inicie con F o B según el comprobante origen (ej. FC01 / BC01)',
            'registro',
            NULL
        );
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NULL THEN
        RETURN json_build_object('error', 'La nota de crédito/débito requiere el comprobante de origen', 'registro', NULL);
    END IF;

    IF p_id_comprobante_origen IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante_origen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante de origen no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT es.nombre
        INTO v_estado_sunat_origen
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        WHERE c.id = p_id_comprobante_origen
          AND c.estado = 1;

        IF COALESCE(v_estado_sunat_origen, '') <> 'ACEPTADO' THEN
            RETURN json_build_object(
                'error',
                'Solo se puede crear nota de crédito/débito sobre un comprobante ACEPTADO por SUNAT',
                'registro',
                NULL
            );
        END IF;
    END IF;

    v_es_nota_credito := (v_codigo_tipo = '07');

    IF p_id_comprobante_origen IS NOT NULL AND v_codigo_tipo IN ('01', '03') THEN
        SELECT lo.descripcion, c.id_almacen
        INTO v_codigo_tipo_origen, v_id_almacen_origen
        FROM ven_comprobante c
        INNER JOIN gen_lista_opciones lo ON c.id_tipo_comprobante = lo.id
        WHERE c.id = p_id_comprobante_origen AND c.estado = 1;

        IF v_codigo_tipo_origen IN ('NV', 'VSD') THEN
            v_es_conversion_vsd := TRUE;

            IF EXISTS (
                SELECT 1
                FROM ven_comprobante
                WHERE id_comprobante_origen = p_id_comprobante_origen
                  AND estado = 1
            ) THEN
                RETURN json_build_object(
                    'error',
                    'Esta venta sin documento ya fue convertida a boleta/factura',
                    'registro',
                    NULL
                );
            END IF;

            IF p_id_condicion_pago IS NULL OR p_fecha_vencimiento IS NULL THEN
                SELECT
                    COALESCE(p_id_condicion_pago, c.id_condicion_pago),
                    COALESCE(p_fecha_vencimiento, c.fecha_vencimiento)
                INTO p_id_condicion_pago, p_fecha_vencimiento
                FROM ven_comprobante c
                WHERE c.id = p_id_comprobante_origen
                  AND c.estado = 1;
            END IF;

            IF p_id_almacen IS NULL THEN
                p_id_almacen := v_id_almacen_origen;
            ELSIF v_id_almacen_origen IS NOT NULL AND p_id_almacen <> v_id_almacen_origen THEN
                RETURN json_build_object(
                    'error',
                    'Al convertir, el almacén debe ser el mismo de la venta sin documento',
                    'registro',
                    NULL
                );
            END IF;
        END IF;
    END IF;

    IF v_codigo_tipo IN ('07', '08') AND p_id_comprobante_origen IS NOT NULL THEN
        SELECT UPPER(TRIM(serie)) INTO v_serie_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        v_familia_origen := left(COALESCE(v_serie_origen, ''), 1);
        IF v_familia_origen IN ('F', 'B') AND left(v_serie, 1) <> v_familia_origen THEN
            RETURN json_build_object(
                'error',
                format(
                    'La serie de la nota debe iniciar con %s igual que el comprobante origen (%s)',
                    v_familia_origen,
                    v_serie_origen
                ),
                'registro',
                NULL
            );
        END IF;
    END IF;

    SELECT (ven_obtener_siguiente_numero(p_id_tipo_comprobante, v_serie)->>'numero')
    INTO v_numero;

    IF v_numero IS NULL OR TRIM(v_numero) = '' THEN
        RETURN json_build_object('error', 'No se pudo asignar el correlativo del comprobante', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM ven_comprobante
        WHERE UPPER(TRIM(serie)) = v_serie AND numero = v_numero
    ) THEN
        RETURN json_build_object(
            'error', 'Ya existe un comprobante con la serie ' || v_serie || ' y número ' || v_numero,
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_sunat
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoSunat'
      AND lo.nombre = CASE
        WHEN v_codigo_tipo IN ('NV', 'VSD') THEN 'NO_APLICA'
        ELSE 'PENDIENTE'
      END
      AND lo.estado = 1
    LIMIT 1;

    IF p_id_estado IS NOT NULL THEN
        v_id_estado_doc := p_id_estado;
    ELSE
        SELECT lo.id INTO v_id_estado_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoDocumento' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT lo.id INTO v_id_estado_cuota
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoCuota' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_producto := NULLIF((v_detalle->>'id_producto')::INTEGER, 0);
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);

        IF v_id_producto IS NULL THEN
            RETURN json_build_object('error', 'Cada detalle debe indicar id_producto', 'registro', NULL);
        END IF;

        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad de cada detalle debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pro_producto WHERE id = v_id_producto AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error',
                'El producto ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                    || ' no existe o está inactivo',
                'registro',
                NULL
            );
        END IF;

        v_id_balon := NULLIF((v_detalle->>'id_balon')::INTEGER, 0);
        IF v_id_balon IS NOT NULL AND NOT v_es_nota_credito
           AND NOT (
               v_es_conversion_vsd
               AND EXISTS (
                   SELECT 1
                   FROM ven_comprobante_detalle od
                   WHERE od.id_comprobante = p_id_comprobante_origen
                     AND od.estado = 1
                     AND od.id_balon = v_id_balon
               )
           )
        THEN
            SELECT UPPER(TRIM(COALESCE(eb.nombre, '')))
            INTO v_nombre_estado_balon
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = v_id_balon AND b.estado = 1
            FOR UPDATE OF b;

            IF NOT FOUND THEN
                RETURN json_build_object(
                    'error',
                    format('El cilindro #%s no existe o está inactivo', v_id_balon),
                    'registro', NULL
                );
            END IF;

            IF v_nombre_estado_balon IN (
                'PENDIENTE_ENVIO', 'EN_TRANSITO', 'EN_MANTENIMIENTO',
                'DADO_DE_BAJA', 'ROBO', 'PRESTADO_CLIENTE', 'EN_PODER_CLIENTE',
                'ALQUILADO', 'EN_RECARGA_EXTERNA', 'POR_RECOGER'
            ) THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'El cilindro no está disponible para venta (estado %s)',
                        LOWER(REPLACE(v_nombre_estado_balon, '_', ' '))
                    ),
                    'registro', NULL
                );
            END IF;
        END IF;

        SELECT
            REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
            COALESCE(p.es_gas, FALSE),
            COALESCE(p.es_servicio, FALSE),
            COALESCE(p.afecta_stock, FALSE)
        INTO v_nombre_unidad, v_es_gas, v_es_servicio, v_afecta_stock
        FROM pro_producto p
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        WHERE p.id = v_id_producto;

        IF NOT COALESCE(v_es_gas, FALSE)
           AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
           AND v_cantidad <> TRUNC(v_cantidad)
        THEN
            RETURN json_build_object(
                'error',
                'La cantidad de ' || COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto)
                    || ' debe ser entera (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;

        IF NOT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion') THEN
            v_afecta_stock := FALSE;
        END IF;

        IF v_afecta_stock AND NOT v_es_conversion_vsd AND v_codigo_tipo <> '08' THEN
            v_requiere_stock := TRUE;
        END IF;

        v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

        v_id_afectacion_igv := NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);
        v_codigo_afectacion := NULL;

        IF v_id_afectacion_igv IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_afectacion_igv
              AND lo.estado = 1;
        END IF;

        IF v_codigo_afectacion IS NULL OR TRIM(v_codigo_afectacion) = '' THEN
            SELECT lo.id, lo.descripcion
            INTO v_id_afectacion_igv, v_codigo_afectacion
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'AfectacionIgv'
              AND lo.descripcion = '10'
              AND lo.estado = 1
            LIMIT 1;

            IF v_id_afectacion_igv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'Cada detalle debe indicar id_afectacion_igv (no se encontró Gravado 10 en catálogo)',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        IF v_codigo_afectacion = '10' THEN
            v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
            v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
        ELSE
            v_valor_linea := v_importe_linea;
            v_impuesto_linea := 0;
            IF v_codigo_afectacion = '20' THEN
                v_exonerado_total := v_exonerado_total + v_valor_linea;
            END IF;
        END IF;

        v_descuento_total := v_descuento_total + v_descuento_linea;
        v_valor_venta_total := v_valor_venta_total + v_valor_linea;
        v_igv_total := v_igv_total + v_impuesto_linea;
        v_sub_total := v_sub_total + v_importe_linea;
        v_total_importe := v_total_importe + v_importe_linea;
    END LOOP;

    IF v_es_nota_credito THEN
        FOR v_id_producto, v_cantidad IN
            SELECT
                (value->>'id_producto')::INTEGER,
                SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
            FROM json_array_elements(p_detalles)
            GROUP BY 1
        LOOP
            SELECT COALESCE(SUM(d.cantidad), 0)
            INTO v_qty_origen
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = p_id_comprobante_origen
              AND d.id_producto = v_id_producto
              AND d.estado = 1;

            SELECT COALESCE(SUM(d.cantidad), 0)
            INTO v_qty_nc_previas
            FROM ven_comprobante nc
            INNER JOIN gen_lista_opciones tc
                ON tc.id = nc.id_tipo_comprobante
               AND tc.descripcion = '07'
            INNER JOIN ven_comprobante_detalle d
                ON d.id_comprobante = nc.id
               AND d.estado = 1
               AND d.id_producto = v_id_producto
            LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
            WHERE nc.id_comprobante_origen = p_id_comprobante_origen
              AND nc.estado = 1
              AND COALESCE(es.nombre, '') NOT IN ('BAJA');

            IF v_cantidad > (v_qty_origen - v_qty_nc_previas) THEN
                RETURN json_build_object(
                    'error',
                    format(
                        'La cantidad a acreditar de %s (%s) supera lo disponible para devolver (%s). Vendida: %s, ya acreditada: %s',
                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                        v_cantidad,
                        GREATEST(v_qty_origen - v_qty_nc_previas, 0),
                        v_qty_origen,
                        v_qty_nc_previas
                    ),
                    'registro',
                    NULL
                );
            END IF;
        END LOOP;
    END IF;

    IF v_requiere_stock THEN
        IF p_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'Debe indicar el almacén para descontar stock de los productos',
                'registro',
                NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF v_es_nota_credito THEN
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'INGRESO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontró el tipo de movimiento de inventario INGRESO',
                    'registro',
                    NULL
                );
            END IF;
        ELSE
            SELECT lo.id INTO v_id_tipo_mov_inv
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'TipoMovInv' AND lo.nombre = 'SALIDA' AND lo.estado = 1
            LIMIT 1;

            IF v_id_tipo_mov_inv IS NULL THEN
                RETURN json_build_object(
                    'error',
                    'No se encontró el tipo de movimiento de inventario SALIDA',
                    'registro',
                    NULL
                );
            END IF;
        END IF;

        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        IF NOT v_es_nota_credito THEN
            FOR v_id_producto, v_cantidad IN
                SELECT
                    (value->>'id_producto')::INTEGER,
                    SUM(COALESCE((value->>'cantidad')::NUMERIC, 0))
                FROM json_array_elements(p_detalles)
                GROUP BY 1
            LOOP
                IF NOT ven_producto_mueve_kardex_venta(v_id_producto, NULL) THEN
                    CONTINUE;
                END IF;

                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF COALESCE(v_stock_disponible, 0) < v_cantidad THEN
                    RETURN json_build_object(
                        'error',
                        format(
                            'Stock insuficiente del producto %s en el almacén (disponible: %s, solicitado: %s)',
                            COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                            COALESCE(v_stock_disponible, 0),
                            v_cantidad
                        ),
                        'registro',
                        NULL
                    );
                END IF;
            END LOOP;
        END IF;
    END IF;

    IF p_id_medio_pago IS NULL AND p_id_condicion_pago IS NOT NULL THEN
        SELECT o.id INTO p_id_medio_pago
        FROM gen_condicion_pago cp
        JOIN gen_lista_opciones o ON UPPER(o.nombre) = 'CREDITO' AND o.estado = 1
        JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
        WHERE cp.id = p_id_condicion_pago
          AND (COALESCE(cp.dias_credito, 0) > 0 OR COALESCE(cp.numero_cuotas, 0) > 1)
        LIMIT 1;
    END IF;

    INSERT INTO ven_comprobante (
        id_tipo_comprobante, serie, numero,
        id_estado_sunat, id_tipo_operacion_sunat,
        id_comprobante_origen, id_motivo_nota,
        id_tipo_movimiento, id_tipo_venta,
        fecha, fecha_vencimiento, tipo_cambio,
        id_cliente, id_sucursal, id_almacen,
        id_condicion_pago, id_moneda, id_medio_pago,
        sub_total, descuento, valor_venta, igv, total_importe,
        exonerado, glosa, observaciones,
        periodo_contable, operacion, origen_pos, id_estado,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_comprobante, v_serie, v_numero,
        v_id_estado_sunat, p_id_tipo_operacion_sunat,
        p_id_comprobante_origen, p_id_motivo_nota,
        p_id_tipo_movimiento, p_id_tipo_venta,
        p_fecha, p_fecha_vencimiento, COALESCE(p_tipo_cambio, 3.5),
        p_id_cliente, p_id_sucursal, p_id_almacen,
        p_id_condicion_pago, p_id_moneda, p_id_medio_pago,
        v_sub_total, v_descuento_total, v_valor_venta_total, v_igv_total, v_total_importe,
        v_exonerado_total, p_glosa, p_observaciones,
        p_periodo_contable, p_operacion, NULLIF(TRIM(p_origen_pos), ''), v_id_estado_doc,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_item := 0;
    v_items_sin_kardex := ARRAY[]::INTEGER[];
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;

        IF COALESCE((v_detalle->>'no_mueve_kardex')::BOOLEAN, FALSE) THEN
            v_items_sin_kardex := v_items_sin_kardex
                || COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item);
        END IF;

        v_id_producto := (v_detalle->>'id_producto')::INTEGER;
        v_cantidad := COALESCE((v_detalle->>'cantidad')::NUMERIC, 0);
        v_precio_unitario := COALESCE((v_detalle->>'precio_unitario')::NUMERIC, 0);
        v_descuento_linea := COALESCE((v_detalle->>'descuento')::NUMERIC, 0);
        v_porcentaje_igv := COALESCE((v_detalle->>'porcentaje_igv')::NUMERIC, 18);
        v_importe_linea := ROUND((v_cantidad * v_precio_unitario) - v_descuento_linea, 4);

        v_id_afectacion_igv := NULLIF((v_detalle->>'id_afectacion_igv')::INTEGER, 0);
        v_codigo_afectacion := NULL;

        IF v_id_afectacion_igv IS NOT NULL THEN
            SELECT lo.descripcion INTO v_codigo_afectacion
            FROM gen_lista_opciones lo
            WHERE lo.id = v_id_afectacion_igv
              AND lo.estado = 1;
        END IF;

        IF v_codigo_afectacion IS NULL OR TRIM(v_codigo_afectacion) = '' THEN
            SELECT lo.id, lo.descripcion
            INTO v_id_afectacion_igv, v_codigo_afectacion
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'AfectacionIgv'
              AND lo.descripcion = '10'
              AND lo.estado = 1
            LIMIT 1;
        END IF;

        IF v_codigo_afectacion = '10' THEN
            v_valor_linea := ROUND(v_importe_linea / (1 + v_porcentaje_igv / 100), 4);
            v_impuesto_linea := ROUND(v_importe_linea - v_valor_linea, 4);
        ELSE
            v_valor_linea := v_importe_linea;
            v_impuesto_linea := 0;
        END IF;

        INSERT INTO ven_comprobante_detalle (
            id_comprobante, item, id_producto, descripcion, id_unidad_medida,
            cantidad, precio_unitario, descuento, valor_venta, porcentaje_igv,
            id_afectacion_igv, impuesto, importe,
            id_balon, capacidad_cilindro, id_estado_cilindro,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id,
            COALESCE(NULLIF((v_detalle->>'item')::INTEGER, 0), v_item),
            v_id_producto,
            NULLIF(v_detalle->>'descripcion', ''),
            NULLIF((v_detalle->>'id_unidad_medida')::INTEGER, 0),
            v_cantidad,
            v_precio_unitario,
            v_descuento_linea,
            v_valor_linea,
            v_porcentaje_igv,
            v_id_afectacion_igv,
            v_impuesto_linea,
            v_importe_linea,
            NULLIF((v_detalle->>'id_balon')::INTEGER, 0),
            NULLIF((v_detalle->>'capacidad_cilindro')::NUMERIC, 0),
            NULLIF((v_detalle->>'id_estado_cilindro')::INTEGER, 0),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    IF v_es_conversion_vsd THEN
        SELECT lo.nombre INTO v_nombre_tipo_venta
        FROM gen_lista_opciones lo
        WHERE lo.id = p_id_tipo_venta;

        v_mov_result := inv_repuntar_documento(
            p_codigo_tipo_documento_origen_actual => ven_resolver_tipo_documento_ref(v_codigo_tipo_origen, v_nombre_tipo_venta),
            p_id_documento_origen_actual          => p_id_comprobante_origen,
            p_codigo_tipo_documento_origen_nuevo  => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
            p_id_documento_origen_nuevo           => v_id,
            p_glosa                               => COALESCE(
                NULLIF(TRIM(p_glosa), ''),
                format('Salida por comprobante %s-%s (desde venta sin documento)', v_serie, v_numero)
            ),
            p_id_usuario_auditoria                => p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;

        FOR v_id_producto, v_qty_origen, v_qty_nueva IN
            SELECT
                COALESCE(o.id_producto, n.id_producto) AS id_producto,
                COALESCE(o.cantidad, 0) AS qty_origen,
                COALESCE(n.cantidad, 0) AS qty_nueva
            FROM (
                SELECT d.id_producto, SUM(d.cantidad) AS cantidad
                FROM ven_comprobante_detalle d
                INNER JOIN pro_producto p ON p.id = d.id_producto
                WHERE d.id_comprobante = p_id_comprobante_origen
                  AND d.estado = 1
                  AND ven_producto_mueve_kardex_venta(p.id, d.descripcion)
                GROUP BY d.id_producto
            ) o
            FULL OUTER JOIN (
                SELECT
                    (value->>'id_producto')::INTEGER AS id_producto,
                    SUM(COALESCE((value->>'cantidad')::NUMERIC, 0)) AS cantidad
                FROM json_array_elements(p_detalles)
                GROUP BY (value->>'id_producto')::INTEGER
            ) n ON n.id_producto = o.id_producto
            INNER JOIN pro_producto p ON p.id = COALESCE(o.id_producto, n.id_producto)
            WHERE ven_producto_mueve_kardex_venta(p.id, NULL)
        LOOP
            v_delta_stock := v_qty_nueva - v_qty_origen;
            IF v_delta_stock = 0 THEN
                CONTINUE;
            END IF;

            IF v_delta_stock > 0 THEN
                SELECT COALESCE(s.stock, 0)
                INTO v_stock_disponible
                FROM pro_stock s
                WHERE s.id_almacen = p_id_almacen
                  AND s.id_producto = v_id_producto
                  AND s.estado = 1;

                IF COALESCE(v_stock_disponible, 0) < v_delta_stock THEN
                    RAISE EXCEPTION
                        'Stock insuficiente del producto % en el almacén (disponible: %, solicitado: %)',
                        COALESCE(pro_etiqueta_producto(v_id_producto), '#' || v_id_producto),
                        COALESCE(v_stock_disponible, 0),
                        v_delta_stock;
                END IF;

                v_mov_result := inv_registrar_movimiento(
                    p_naturaleza => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'SALIDA',
                    p_fecha => p_fecha,
                    p_id_producto => v_id_producto,
                    p_cantidad => v_delta_stock,
                    p_id_almacen_origen => p_id_almacen,
                    p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                    p_id_documento_origen => v_id,
                    p_glosa => format('Ajuste conversión %s-%s (+)', v_serie, v_numero),
                    p_id_usuario_auditoria => p_id_usuario_auditoria,
                    p_forzar => TRUE
                );
            ELSE
                v_mov_result := inv_registrar_movimiento(
                    p_naturaleza => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'INGRESO',
                    p_fecha => p_fecha,
                    p_id_producto => v_id_producto,
                    p_cantidad => ABS(v_delta_stock),
                    p_id_almacen_origen => p_id_almacen,
                    p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                    p_id_documento_origen => v_id,
                    p_glosa => format('Ajuste conversión %s-%s (-)', v_serie, v_numero),
                    p_id_usuario_auditoria => p_id_usuario_auditoria,
                    p_forzar => TRUE
                );
            END IF;

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
        END LOOP;
    ELSIF v_requiere_stock THEN
        v_glosa_mov := COALESCE(
            NULLIF(TRIM(p_glosa), ''),
            CASE
                WHEN v_es_nota_credito THEN
                    format('Ingreso por nota de crédito %s-%s', v_serie, v_numero)
                ELSE
                    format('Salida por comprobante %s-%s', v_serie, v_numero)
            END
        );

        FOR v_id_detalle, v_id_producto, v_cantidad, v_detalle IN
            SELECT d.id, d.id_producto, d.cantidad, to_json(d.*)
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id AND d.estado = 1
            ORDER BY d.id
        LOOP
            SELECT ven_producto_mueve_kardex_venta(v_id_producto, v_detalle->>'descripcion')
            INTO v_afecta_stock;

            IF (v_detalle->>'item')::INTEGER = ANY(v_items_sin_kardex) THEN
                CONTINUE;
            END IF;

            IF v_es_nota_credito
               AND p_id_comprobante_origen IS NOT NULL
               AND EXISTS (
                    SELECT 1
                    FROM ven_comprobante_detalle od
                    WHERE od.id_comprobante = p_id_comprobante_origen
                      AND od.estado = 1
                      AND od.id_producto = v_id_producto
                      AND od.id_balon IS NOT NULL
               ) THEN
                CONTINUE;
            END IF;

            IF NOT v_afecta_stock THEN
                CONTINUE;
            END IF;

            IF v_es_nota_credito
               AND p_id_comprobante_origen IS NOT NULL
               AND EXISTS (
                   SELECT 1
                   FROM ven_comprobante_detalle od
                   WHERE od.id_comprobante = p_id_comprobante_origen
                     AND od.id_producto = v_id_producto
                     AND od.id_balon IS NOT NULL
                     AND od.estado = 1
               )
            THEN
                CONTINUE;
            END IF;

            v_mov_result := inv_registrar_movimiento(
                p_naturaleza => 'PRODUCTO',
                p_codigo_tipo_movimiento => CASE WHEN v_es_nota_credito THEN 'INGRESO' ELSE 'SALIDA' END,
                p_fecha => p_fecha,
                p_id_producto => v_id_producto,
                p_cantidad => v_cantidad,
                p_id_almacen_origen => p_id_almacen,
                p_codigo_tipo_documento_origen => ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta),
                p_id_documento_origen => v_id,
                p_glosa => v_glosa_mov,
                p_id_usuario_auditoria => p_id_usuario_auditoria,
                p_id_documento_detalle => v_id_detalle
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov_result->>'error';
            END IF;
            IF COALESCE((v_mov_result->>'creado')::boolean, TRUE) IS NOT TRUE THEN
                RAISE EXCEPTION 'No se registró el movimiento de stock (duplicado) para el producto %', v_id_producto;
            END IF;
        END LOOP;
    END IF;

    IF p_cuotas IS NOT NULL AND json_typeof(p_cuotas) = 'array' THEN
        FOR v_cuota IN SELECT value FROM json_array_elements(p_cuotas)
        LOOP
            v_numero_cuota := COALESCE((v_cuota->>'numero_cuota')::INTEGER, 0);
            IF v_numero_cuota <= 0 THEN
                CONTINUE;
            END IF;

            INSERT INTO ven_cuotas (
                id_comprobante, numero_cuota, fecha_vencimiento, monto,
                monto_pagado, id_estado,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_numero_cuota,
                (v_cuota->>'fecha_vencimiento')::DATE,
                COALESCE((v_cuota->>'monto')::NUMERIC, 0),
                COALESCE((v_cuota->>'monto_pagado')::NUMERIC, 0),
                COALESCE(NULLIF((v_cuota->>'id_estado')::INTEGER, 0), v_id_estado_cuota),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    IF v_es_conversion_vsd AND p_id_comprobante_origen IS NOT NULL THEN
        UPDATE fin_cuenta
        SET
            id_comprobante_venta = v_id,
            numero_comprobante = v_serie || '-' || v_numero,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_comprobante_venta = p_id_comprobante_origen
          AND estado = 1;
    END IF;

    IF NOT v_es_nota_credito
       AND p_id_condicion_pago IS NOT NULL
       AND COALESCE(v_total_importe, 0) > 0
    THEN
        SELECT
            COALESCE(cp.dias_credito, 0),
            COALESCE(cp.numero_cuotas, 0),
            cp.dia_mes_pago
        INTO v_dias_credito, v_numero_cuotas, v_dia_mes_pago
        FROM gen_condicion_pago cp
        WHERE cp.id = p_id_condicion_pago
          AND cp.estado = 1;

        IF v_dias_credito > 0 OR v_numero_cuotas > 1 THEN
            IF EXISTS (
                SELECT 1
                FROM cli_clientes c
                WHERE c.id = p_id_cliente
                  AND UPPER(COALESCE(c.codigo_interno, '')) = 'CVARIOS'
            ) THEN
                RAISE EXCEPTION
                    'No se puede vender a crédito a Clientes Varios. Selecciona un cliente identificado.';
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM fin_cuenta fc
                WHERE fc.id_comprobante_venta = v_id
                  AND fc.estado = 1
            ) THEN
                IF v_numero_cuotas > 1 THEN
                    IF v_dia_mes_pago IS NULL OR v_dia_mes_pago < 1 OR v_dia_mes_pago > 31 THEN
                        RAISE EXCEPTION
                            'La condición de pago en cuotas requiere día del mes a cobrar (1 a 31).';
                    END IF;

                    IF p_fecha_vencimiento IS NOT NULL THEN
                        v_fecha_primera_cuota := p_fecha_vencimiento;
                    ELSIF v_dias_credito > 0 THEN
                        v_fecha_primera_cuota := COALESCE(p_fecha, CURRENT_DATE) + v_dias_credito;
                    ELSE
                        v_mes_base := date_trunc('month', COALESCE(p_fecha, CURRENT_DATE))::date;
                        v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                        v_fecha_primera_cuota := LEAST(
                            (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                            v_ultimo_dia_mes
                        );
                        IF v_fecha_primera_cuota < COALESCE(p_fecha, CURRENT_DATE) THEN
                            v_mes_base := (v_mes_base + INTERVAL '1 month')::date;
                            v_ultimo_dia_mes := (v_mes_base + INTERVAL '1 month - 1 day')::date;
                            v_fecha_primera_cuota := LEAST(
                                (v_mes_base + ((v_dia_mes_pago - 1) * INTERVAL '1 day'))::date,
                                v_ultimo_dia_mes
                            );
                        END IF;
                    END IF;

                    UPDATE ven_comprobante
                    SET fecha_vencimiento = v_fecha_primera_cuota
                    WHERE id = v_id
                      AND fecha_vencimiento IS NULL;

                    v_cxc_result := fin_crear_cuenta_cuotas(
                        'COBRAR',
                        p_id_cliente,
                        NULL,
                        COALESCE(p_fecha, CURRENT_DATE),
                        v_total_importe,
                        v_numero_cuotas,
                        v_fecha_primera_cuota,
                        v_dia_mes_pago,
                        format(
                            'CxC en %s cuotas (día %s) %s-%s',
                            v_numero_cuotas,
                            v_dia_mes_pago,
                            v_serie,
                            v_numero
                        ),
                        NULL,
                        NULL,
                        NULL,
                        v_serie || '-' || v_numero,
                        p_id_usuario_auditoria,
                        v_id
                    );

                    IF v_cxc_result->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION '%', v_cxc_result->>'error';
                    END IF;
                ELSE
                    v_fecha_venc_cxc := COALESCE(
                        p_fecha_vencimiento,
                        (COALESCE(p_fecha, CURRENT_DATE) + v_dias_credito)
                    );

                    IF p_fecha_vencimiento IS NULL THEN
                        UPDATE ven_comprobante
                        SET fecha_vencimiento = v_fecha_venc_cxc
                        WHERE id = v_id;
                    END IF;

                    SELECT glo.id
                    INTO v_id_tipo_cobrar
                    FROM gen_lista_opciones glo
                    JOIN gen_lista gl ON gl.id = glo.id_lista
                    WHERE gl.nombre = 'TipoCuentaFinanciera'
                      AND glo.nombre = 'COBRAR'
                      AND glo.estado = 1
                    LIMIT 1;

                    IF v_id_tipo_cobrar IS NULL THEN
                        RAISE EXCEPTION
                            'No está configurado el tipo de cuenta COBRAR (TipoCuentaFinanciera).';
                    END IF;

                    INSERT INTO fin_cuenta (
                        id_tipo_cuenta,
                        id_tercero,
                        id_comprobante_venta,
                        numero_comprobante,
                        fecha_emision,
                        fecha_vencimiento,
                        monto_pendiente,
                        monto_abonado,
                        monto_saldo,
                        descripcion,
                        id_usuario_creacion,
                        id_usuario_modificacion
                    ) VALUES (
                        v_id_tipo_cobrar,
                        p_id_cliente,
                        v_id,
                        v_serie || '-' || v_numero,
                        COALESCE(p_fecha, CURRENT_DATE),
                        v_fecha_venc_cxc,
                        v_total_importe,
                        0,
                        v_total_importe,
                        format(
                            'CxC por venta a crédito (%s días) %s-%s',
                            v_dias_credito,
                            v_serie,
                            v_numero
                        ),
                        p_id_usuario_auditoria,
                        p_id_usuario_auditoria
                    );
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_es_nota_credito
       AND p_id_comprobante_origen IS NOT NULL
       AND COALESCE(v_total_importe, 0) > 0
    THEN
        PERFORM fin_abonar_por_nota_credito(
            p_id_comprobante_origen,
            v_id,
            v_total_importe,
            p_id_usuario_auditoria
        );

        SELECT total_importe INTO v_total_origen
        FROM ven_comprobante
        WHERE id = p_id_comprobante_origen AND estado = 1;

        IF COALESCE(v_total_importe, 0) >= COALESCE(v_total_origen, 0) - 0.05
           OR EXISTS (
               SELECT 1
               FROM ven_comprobante_detalle d
               WHERE d.id_comprobante = v_id
                 AND d.estado = 1
                 AND d.id_balon IS NOT NULL
           )
        THEN
            PERFORM ven_cerrar_custodia_comprobante(
                p_id_comprobante_origen,
                p_id_usuario_auditoria
            );
        END IF;
    END IF;

    IF p_efectos_pos IS NOT NULL AND p_efectos_pos::TEXT NOT IN ('null', '{}', '[]') THEN
        PERFORM ven_aplicar_efectos_pos(v_id, p_efectos_pos, p_id_usuario_auditoria);
    END IF;

    IF NOT v_es_nota_credito
       AND EXISTS (
           SELECT 1
           FROM ven_comprobante_detalle d
           WHERE d.id_comprobante = v_id
             AND d.estado = 1
             AND d.id_balon IS NOT NULL
             AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
       )
    THEN
        SELECT lo.id INTO v_id_estado_pendiente_envio
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'PENDIENTE_ENVIO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_pendiente_envio IS NULL THEN
            RAISE EXCEPTION 'Falta el estado PENDIENTE_ENVIO en el catálogo EstadoBalon';
        END IF;

        SELECT lo.id INTO v_id_estado_disponible
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_disponible IS NOT NULL THEN
            UPDATE bal_balon b
            SET id_estado_balon = v_id_estado_pendiente_envio,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id
              AND d.estado = 1
              AND d.id_balon = b.id
              AND b.estado = 1
              AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
              AND b.id_estado_balon = v_id_estado_disponible;
        END IF;
    END IF;

    v_err_pagos := ven_sincronizar_pagos_comprobante(v_id, p_pagos, p_id_usuario_auditoria);
    IF v_err_pagos IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pagos USING ERRCODE = '22023';
    END IF;

    RETURN ven_obtener_comprobante(v_id);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_eliminar_comprobante (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.ven_eliminar_comprobante (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_sunat VARCHAR;
    v_rev JSON;
    v_anul JSON;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_os_id INTEGER;
    v_id_almacen_venta INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    PERFORM 1 FROM ven_comprobante WHERE id = p_id AND estado = 1 FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante=p_id AND tipo='CAMBIO_BALON' AND datos->>'tipoOperacion'='CAMBIO') THEN
        RAISE EXCEPTION 'La venta tiene cambios físicos registrados. No se puede eliminar ni restaurar automáticamente su inventario original';
    END IF;

    SELECT es.nombre, c.serie, c.numero, c.id_almacen
    INTO v_estado_sunat, v_serie, v_numero, v_id_almacen_venta
    FROM ven_comprobante c
    LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
    WHERE c.id = p_id AND c.estado = 1;

    IF v_estado_sunat IN ('ACEPTADO', 'BAJA') THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar un comprobante ya aceptado por SUNAT. Use nota de crédito o comunicación de baja.'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_comprobante
        WHERE id_comprobante_origen = p_id
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el comprobante porque tiene documentos derivados (boleta/factura/nota)'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        JOIN age_actividad a ON a.id_doc_salida = d.id AND a.estado = 1
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'REPARTO'
          AND UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA'
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error',
            'La entrega de esta venta ya fue realizada y los cilindros están en poder del cliente; '
            || 'no se puede anular. Emite una nota de crédito y registra la devolución.'
        );
    END IF;

    FOR v_os_id IN
        SELECT d.id
        FROM doc_salida d
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        WHERE d.id_venta = p_id
          AND d.estado = 1
          AND ec.nombre <> 'ANULADA'
    LOOP
        v_anul := doc_anular_salida(
            v_os_id,
            format('Venta %s-%s anulada', COALESCE(v_serie, ''), COALESCE(v_numero, p_id::text)),
            p_id_usuario_auditoria
        );
        IF v_anul->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_anul->>'error';
        END IF;
    END LOOP;

    UPDATE bal_balon b
    SET id_estado_balon = lo_disp.id,
        id_almacen = COALESCE(b.id_almacen, v_id_almacen_venta),
        id_cliente_ubicacion = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM ven_comprobante_detalle d
    CROSS JOIN LATERAL (
        SELECT lo.id
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1
    ) lo_disp
    CROSS JOIN gen_lista_opciones eb
    WHERE d.id_comprobante = p_id
      AND d.estado = 1
      AND d.id_balon = b.id
      AND eb.id = b.id_estado_balon
      AND b.estado = 1
      AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
      AND lo_disp.id IS NOT NULL
      AND UPPER(TRIM(eb.nombre)) IN ('PENDIENTE_ENVIO', 'EN_PODER_CLIENTE');

    v_rev := ven_revertir_efectos_comprobante(p_id, p_id_usuario_auditoria, TRUE);
    IF COALESCE(v_rev->>'ok', 'false') <> 'true' THEN
        RAISE EXCEPTION '%', COALESCE(v_rev->>'error', 'No se pudieron revertir los efectos del comprobante');
    END IF;

    UPDATE ven_comprobante_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_cuotas
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante_pago
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE ven_comprobante
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', SQLERRM);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_obtener_comprobante (p_id integer);

CREATE OR REPLACE FUNCTION public.ven_obtener_comprobante (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_cuotas JSON;
    v_pagos JSON;
    v_prestamos JSON;
    v_garantias JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.xmin::text AS version,
            ven_comprobante_permite_edicion(c) AS permite_edicion_segura,
            EXISTS(SELECT 1 FROM ven_vsd_operacion o WHERE o.id_comprobante=c.id AND o.tipo='CAMBIO_BALON' AND o.datos->>'tipoOperacion'='CAMBIO') AS tiene_cambio_fisico,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_tipo_operacion_sunat,
            tos.nombre AS nombre_tipo_operacion_sunat,
            tos.descripcion AS codigo_tipo_operacion_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.ticket_sunat,
            c.hash_documento,
            c.xml_firmado,
            c.cdr_respuesta,
            c.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            c.id_tipo_venta,
            tv.nombre AS nombre_tipo_venta,
            c.fecha,
            c.fecha_vencimiento,
            c.tipo_cambio,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_sucursal,
            su.nombre AS nombre_sucursal,
            c.id_almacen,
            al.nombre AS nombre_almacen,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            COALESCE(cp.dias_credito, 0) AS dias_credito,
            COALESCE(cp.numero_cuotas, 0) AS numero_cuotas,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            mo.descripcion AS codigo_moneda,
            c.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            c.sub_total,
            c.descuento,
            c.valor_venta,
            c.igv,
            c.total_importe,
            c.anticipos,
            c.exonerado,
            c.glosa,
            c.observaciones,
            c.periodo_contable,
            c.operacion,
            c.origen_pos,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            act.nombre_chofer_responsable,
            (act.id IS NOT NULL) AS tiene_actividad,
            docsal.id AS id_doc_salida,
            docsal.numero AS numero_doc_salida
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones tos ON c.id_tipo_operacion_sunat = tos.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN gen_lista_opciones tm ON c.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_sucursal su ON c.id_sucursal = su.id
        LEFT JOIN gen_almacen al ON c.id_almacen = al.id
        LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN gen_lista_opciones mp ON c.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad,
                TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            LEFT JOIN gen_chofer ch ON ch.id = a.id_chofer_responsable
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        LEFT JOIN LATERAL (
            SELECT d.id, d.numero
            FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = c.id
              AND d.estado = 1
              AND ec.nombre <> 'ANULADA'
            ORDER BY d.id DESC
            LIMIT 1
        ) docsal ON TRUE
        WHERE c.id = p_id AND c.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON) INTO v_detalles
    FROM (
        SELECT
            d.id,
            d.id_comprobante,
            d.item,
            d.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.es_gas,
            p.es_servicio,
            p.es_alquilable,
            d.descripcion,
            d.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            d.cantidad,
            COALESCE((
                SELECT SUM(nd.cantidad)
                FROM ven_comprobante nc
                INNER JOIN gen_lista_opciones tc
                    ON tc.id = nc.id_tipo_comprobante
                   AND tc.descripcion = '07'
                INNER JOIN ven_comprobante_detalle nd
                    ON nd.id_comprobante = nc.id
                   AND nd.estado = 1
                   AND nd.id_producto = d.id_producto
                LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
                WHERE nc.id_comprobante_origen = p_id
                  AND nc.estado = 1
                  AND COALESCE(es.nombre, '') NOT IN ('BAJA')
            ), 0) AS cantidad_nc_previa,
            GREATEST(
                d.cantidad - COALESCE((
                    SELECT SUM(nd.cantidad)
                    FROM ven_comprobante nc
                    INNER JOIN gen_lista_opciones tc
                        ON tc.id = nc.id_tipo_comprobante
                       AND tc.descripcion = '07'
                    INNER JOIN ven_comprobante_detalle nd
                        ON nd.id_comprobante = nc.id
                       AND nd.estado = 1
                       AND nd.id_producto = d.id_producto
                    LEFT JOIN gen_lista_opciones es ON es.id = nc.id_estado_sunat
                    WHERE nc.id_comprobante_origen = p_id
                      AND nc.estado = 1
                      AND COALESCE(es.nombre, '') NOT IN ('BAJA')
                ), 0),
                0
            ) AS cantidad_disponible_nc,
            d.precio_unitario,
            d.descuento,
            d.valor_venta,
            d.porcentaje_igv,
            d.id_afectacion_igv,
            ai.nombre AS nombre_afectacion_igv,
            ai.descripcion AS codigo_afectacion_igv,
            d.impuesto,
            d.importe,
            d.id_balon,
            b.codigo_balon,
            d.capacidad_cilindro,
            d.id_estado_cilindro,
            ec.nombre AS nombre_estado_cilindro,
            (COALESCE(d.descripcion, '') ~* 'garant[ií]a') AS es_linea_garantia,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON d.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON d.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones ai ON d.id_afectacion_igv = ai.id
        LEFT JOIN bal_balon b ON d.id_balon = b.id
        LEFT JOIN gen_lista_opciones ec ON d.id_estado_cilindro = ec.id
        WHERE d.id_comprobante = p_id AND d.estado = 1
    ) d;

    SELECT COALESCE(json_agg(row_to_json(q) ORDER BY q.numero_cuota), '[]'::JSON) INTO v_cuotas
    FROM (
        SELECT
            q.id,
            q.id_comprobante,
            q.numero_cuota,
            q.fecha_vencimiento,
            q.monto,
            q.monto_pagado,
            q.id_estado,
            eq.nombre AS nombre_estado,
            q.estado,
            q.fecha_creacion,
            q.fecha_modificacion
        FROM ven_cuotas q
        LEFT JOIN gen_lista_opciones eq ON q.id_estado = eq.id
        WHERE q.id_comprobante = p_id AND q.estado = 1
    ) q;

    SELECT COALESCE(json_agg(row_to_json(pg) ORDER BY pg.item), '[]'::JSON) INTO v_pagos
    FROM (
        SELECT
            pp.id,
            pp.item,
            pp.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            pp.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            pp.monto,
            pp.numero_operacion,
            pp.referencia,
            pp.observacion
        FROM ven_comprobante_pago pp
        LEFT JOIN gen_lista_opciones mp ON mp.id = pp.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pp.id_cuenta_bancaria
        WHERE pp.id_comprobante = p_id AND pp.estado = 1
    ) pg;

    SELECT COALESCE(json_agg(row_to_json(pr) ORDER BY pr.id), '[]'::JSON) INTO v_prestamos
    FROM (
        SELECT
            p.id,
            p.numero_prestamo,
            p.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            p.id_almacen,
            a.nombre AS nombre_almacen,
            p.fecha_salida,
            p.fecha_retorno_pactada,
            p.fecha_retorno_real,
            p.titulo,
            p.observacion,
            p.id_estado,
            ep.nombre AS nombre_estado,
            p.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            (
                SELECT COALESCE(json_agg(row_to_json(bl) ORDER BY bl.rol, bl.id), '[]'::JSON)
                FROM (
                    SELECT
                        pd.id,
                        pd.rol,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie,
                        b.id_tipo_balon,
                        tb.nombre AS nombre_tipo_balon,
                        tb.capacidad,
                        b.id_estado_balon,
                        eb.nombre AS nombre_estado_balon,
                        pd.id_producto,
                        COALESCE(pgas.nombre, prod.nombre) AS nombre_producto,
                        pd.fecha_entregado,
                        pd.fecha_prestamo,
                        pd.fecha_vencimiento,
                        pd.fecha_devolucion,
                        pd.id_estado,
                        epd.nombre AS nombre_estado,
                        pd.motivo_especifico,
                        pd.observacion
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                    LEFT JOIN pro_producto prod ON prod.id = pd.id_producto
                    LEFT JOIN pro_producto pgas ON pgas.id = b.id_producto_gas
                    LEFT JOIN gen_lista_opciones epd ON epd.id = pd.id_estado
                    WHERE pd.id_prestamo = p.id AND pd.estado = 1
                ) bl
            ) AS balones
        FROM bal_prestamo p
        LEFT JOIN gen_lista_opciones tp ON tp.id = p.id_tipo_prestamo
        LEFT JOIN gen_almacen a ON a.id = p.id_almacen
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        LEFT JOIN bal_prestamo po ON po.id = p.id_prestamo_origen
        WHERE p.id_comprobante_venta = p_id AND p.estado = 1
    ) pr;

    SELECT COALESCE(json_agg(row_to_json(gr) ORDER BY gr.id), '[]'::JSON) INTO v_garantias
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.id_alquiler,
            alq.numero_alquiler,
            g.id_producto,
            prod.nombre AS nombre_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            umg.nombre AS nombre_unidad_medida,
            g.ubicacion,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.id_medio_pago,
            mpg.nombre AS nombre_medio_pago,
            g.observacion,
            COALESCE((
                SELECT SUM(gm.monto)
                FROM ven_garantia_movimiento gm
                INNER JOIN gen_lista_opciones tmg ON tmg.id = gm.id_tipo_movimiento
                WHERE gm.id_garantia = g.id
                  AND gm.id_comprobante = p_id
                  AND gm.estado = 1
                  AND UPPER(tmg.nombre) = 'COBRO'
            ), 0) AS monto_cobrado_comprobante
        FROM ven_garantia g
        LEFT JOIN bal_prestamo pr ON pr.id = g.id_prestamo
        LEFT JOIN bal_alquiler alq ON alq.id = g.id_alquiler
        LEFT JOIN pro_producto prod ON prod.id = g.id_producto
        LEFT JOIN gen_lista_opciones umg ON umg.id = g.id_unidad_medida
        LEFT JOIN gen_lista_opciones eg ON eg.id = g.id_estado
        LEFT JOIN gen_lista_opciones mpg ON mpg.id = g.id_medio_pago
        WHERE g.estado = 1
          AND (
              pr.id_comprobante_venta = p_id
              OR alq.id_comprobante_venta = p_id
              OR EXISTS (
                  SELECT 1
                  FROM ven_garantia_movimiento gm
                  WHERE gm.id_garantia = g.id
                    AND gm.id_comprobante = p_id
                    AND gm.estado = 1
              )
          )
    ) gr;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles,
        'cuotas', v_cuotas,
        'pagos', v_pagos,
        'prestamos', v_prestamos,
        'garantias', v_garantias
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.ven_proteger_numeracion_correccion () RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
 IF NEW.serie IS NOT DISTINCT FROM OLD.serie AND NEW.numero IS NOT DISTINCT FROM OLD.numero
    AND NEW.id_tipo_comprobante IS NOT DISTINCT FROM OLD.id_tipo_comprobante THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ven_cpe_correccion_reserva r JOIN ven_cpe_correccion_lote l ON l.id=r.id_lote
   WHERE r.id_comprobante=OLD.id AND l.numeracion_bloqueada) THEN
   RAISE EXCEPTION 'La numeración de este comprobante quedó bloqueada para uso del cliente. Se conserva %-%; no se permite renumerar ni convertir su tipo.',OLD.serie,OLD.numero USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.ven_proteger_numeracion_nota_correccion () RETURNS trigger LANGUAGE plpgsql AS $function$
BEGIN
 IF NEW.serie IS NOT DISTINCT FROM OLD.serie AND NEW.numero IS NOT DISTINCT FROM OLD.numero
    AND NEW.serie_original IS NOT DISTINCT FROM OLD.serie_original AND NEW.numero_original IS NOT DISTINCT FROM OLD.numero_original THEN RETURN NEW; END IF;
 IF EXISTS(SELECT 1 FROM ven_cpe_correccion_lote l WHERE l.id=OLD.id_lote AND l.numeracion_bloqueada) THEN
   RAISE EXCEPTION 'La referencia de la nota fiscal %-% y su comprobante original están bloqueados.',OLD.serie,OLD.numero USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_registrar_respuesta_sunat (
  p_id integer,
  p_id_estado_sunat integer,
  p_ticket_sunat character varying,
  p_hash_documento character varying,
  p_xml_firmado text,
  p_cdr_respuesta text,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.ven_registrar_respuesta_sunat (
  p_id integer,
  p_id_estado_sunat integer DEFAULT NULL::integer,
  p_ticket_sunat character varying DEFAULT NULL::character varying,
  p_hash_documento character varying DEFAULT NULL::character varying,
  p_xml_firmado text DEFAULT NULL::text,
  p_cdr_respuesta text DEFAULT NULL::text,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_sunat_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_estado_sunat IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_estado_sunat AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El estado SUNAT indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT nombre INTO v_estado_sunat_nombre
    FROM gen_lista_opciones
    WHERE id = p_id_estado_sunat;

    PERFORM 1 FROM ven_comprobante WHERE id=p_id FOR UPDATE;
    IF v_estado_sunat_nombre IN ('PENDIENTE', 'RECHAZADO') AND EXISTS (
        SELECT 1 FROM ven_comprobante c WHERE c.id=p_id AND ven_cpe_validez_aceptada(c)
    ) THEN RETURN ven_obtener_comprobante(p_id); END IF;
    UPDATE ven_comprobante
    SET
        id_estado_sunat = COALESCE(p_id_estado_sunat, id_estado_sunat),
        ticket_sunat = COALESCE(NULLIF(TRIM(p_ticket_sunat), ''), ticket_sunat),
        hash_documento = COALESCE(NULLIF(TRIM(p_hash_documento), ''), hash_documento),
        xml_firmado = COALESCE(p_xml_firmado, xml_firmado),
        cdr_respuesta = COALESCE(p_cdr_respuesta, cdr_respuesta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_estado_sunat_nombre = 'ACEPTADO' THEN
        UPDATE ven_comprobante c
        SET id_estado = lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE c.id = p_id
          AND l.nombre = 'EstadoDocumento'
          AND lo.nombre = 'PAGADO'
          AND lo.estado = 1
          AND c.id_estado IS DISTINCT FROM lo.id;
    END IF;

    RETURN ven_obtener_comprobante(p_id);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_regularizar_comprobante (
  p_id integer,
  p_serie character varying,
  p_fecha_emision date,
  p_verificacion jsonb,
  p_cdr_esperado text,
  p_numero_esperado character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.ven_regularizar_comprobante (
  p_id integer,
  p_serie character varying,
  p_fecha_emision date,
  p_verificacion jsonb,
  p_cdr_esperado text,
  p_numero_esperado character varying,
  p_id_usuario_auditoria integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_doc RECORD;
    v_destino VARCHAR;
    v_id_tipo_destino INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_label_anterior VARCHAR;
    v_label_nuevo VARCHAR;
    v_ref_anterior VARCHAR;
    v_ref_nuevo VARCHAR;
    v_id_ref_anterior INTEGER;
    v_id_ref_nuevo INTEGER;
    v_id_pendiente INTEGER;
    v_tiene_envio BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT pg_try_advisory_xact_lock(872016, p_id) THEN
        RETURN json_build_object('error', 'Hay una emisión a SUNAT en curso para este comprobante; espera a que termine.', 'registro', NULL);
    END IF;

    SELECT c.*, tc.descripcion AS codigo_tipo, es.nombre AS estado_sunat,
           COALESCE(tv.nombre, 'VENTA') AS nombre_tipo_venta,
           cli.numero_documento AS documento_cliente
    INTO v_doc
    FROM ven_comprobante c
    JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
    LEFT JOIN gen_lista_opciones tv ON tv.id = c.id_tipo_venta
    LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
    WHERE c.id = p_id AND c.estado = 1
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_verificacion->>'consultadoEn' IS NULL OR abs(extract(epoch from (now() - (p_verificacion->>'consultadoEn')::timestamptz))) > 300 THEN
        RETURN json_build_object('error','La consulta de validez venció. Repite la verificación antes de regularizar.','registro',NULL);
    END IF;
    v_destino := v_doc.codigo_tipo;

    IF v_doc.codigo_tipo NOT IN ('01', '03') THEN
        RETURN json_build_object('error', 'Solo se puede convertir una boleta o una factura', 'registro', NULL);
    END IF;
    IF v_destino NOT IN ('01', '03') THEN
        RETURN json_build_object('error', 'El tipo destino debe ser 01 (factura) o 03 (boleta)', 'registro', NULL);
    END IF;

    IF p_verificacion->>'codigo' IS DISTINCT FROM '0'
       OR p_verificacion->'consulta'->>'numeroSerie' IS DISTINCT FROM v_doc.serie
       OR (p_verificacion->'consulta'->>'numero')::bigint IS DISTINCT FROM v_doc.numero::bigint
       OR (p_verificacion->'consulta'->>'monto')::numeric IS DISTINCT FROM v_doc.total_importe
       OR p_verificacion->'consulta'->>'fechaEmision' IS DISTINCT FROM to_char(COALESCE(v_doc.fecha_emision_cpe,v_doc.fecha), 'DD/MM/YYYY')
       OR v_doc.cdr_respuesta IS DISTINCT FROM p_cdr_esperado
    THEN
        RETURN json_build_object('error','La verificación de validez no corresponde a la versión actual del comprobante.','registro',NULL);
    END IF;
    IF p_fecha_emision IS DISTINCT FROM (now() AT TIME ZONE 'America/Lima')::date THEN
        RETURN json_build_object('error','El reemplazo debe usar la fecha actual de emisión. La fecha original de la venta se conserva.','registro',NULL);
    END IF;
    IF upper(trim(p_serie)) NOT IN ('F002','B002') OR upper(trim(p_serie)) = v_doc.serie THEN
        RETURN json_build_object('error','Esta regularización utiliza una serie nueva F002 o B002.','registro',NULL);
    END IF;

    IF v_doc.estado_sunat = 'BAJA' THEN
        RETURN json_build_object(
            'error', 'El comprobante ya está ' || v_doc.estado_sunat || ' en SUNAT: no se puede regularizar. Emite una nota de crédito y un comprobante nuevo.',
            'registro', NULL
        );
    END IF;

    v_tiene_envio := NULLIF(TRIM(COALESCE(v_doc.ticket_sunat, '')), '') IS NOT NULL
        OR v_doc.hash_documento IS NOT NULL
        OR v_doc.xml_firmado IS NOT NULL
        OR v_doc.cdr_respuesta IS NOT NULL;

    IF EXISTS (
        SELECT 1
        FROM ven_resumen_diario_detalle rd
        JOIN ven_resumen_diario r ON r.id = rd.id_resumen AND r.estado = 1
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado_sunat
        WHERE rd.id_comprobante = p_id AND rd.estado = 1
          AND COALESCE(er.nombre, '') <> 'RECHAZADO'
    ) THEN
        RETURN json_build_object('error', 'La boleta está incluida en un resumen diario enviado a SUNAT: no se puede regularizar.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El comprobante tiene notas u otros documentos derivados: no se puede regularizar.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_percepcion_detalle WHERE id_comprobante = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El comprobante figura en un comprobante de percepción: no se puede regularizar.', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        WHERE d.estado = 1
          AND (d.id_venta = p_id OR EXISTS (
                SELECT 1 FROM doc_salida_referencia r
                WHERE r.id_doc_salida = d.id AND r.id_comprobante = p_id AND r.estado = 1))
          AND (d.emitido_sunat
               OR NULLIF(TRIM(COALESCE(d.ticket_sunat, '')), '') IS NOT NULL
               OR EXISTS (SELECT 1 FROM doc_gre_intento i WHERE i.id_doc_salida = d.id AND i.estado <> 'RECHAZADO'))
    ) THEN
        RETURN json_build_object(
            'error', 'La guía de remisión de esta venta ya se envió a SUNAT citando su número actual: no se puede regularizar.',
            'registro', NULL
        );
    END IF;

    IF v_destino = '01' AND COALESCE(TRIM(v_doc.documento_cliente), '') !~ '^[0-9]{11}$' THEN
        RETURN json_build_object('error', 'La factura requiere un cliente con RUC (11 dígitos). Cambia el cliente antes de convertir.', 'registro', NULL);
    END IF;

    v_serie := UPPER(TRIM(COALESCE(p_serie, '')));
    IF v_serie = '' THEN
        v_serie := CASE WHEN v_destino = '01' THEN 'F' ELSE 'B' END
            || CASE WHEN UPPER(TRIM(v_doc.serie)) ~ '^[FB][0-9]{3}$' THEN substr(UPPER(TRIM(v_doc.serie)), 2) ELSE '001' END;
    END IF;

    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object('error', 'La serie electrónica debe tener 4 caracteres (ej. F001, B001)', 'registro', NULL);
    END IF;
    IF v_destino = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;
    IF v_destino = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_destino
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoComprobante' AND lo.descripcion = v_destino AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_destino IS NULL THEN
        RETURN json_build_object('error', format('Tipo de comprobante %s no configurado', v_destino), 'registro', NULL);
    END IF;

    v_numero := ven_obtener_siguiente_numero(v_id_tipo_destino, v_serie)->>'numero';
    IF v_numero IS NULL OR TRIM(v_numero) = '' THEN
        RETURN json_build_object('error', 'No se pudo asignar el correlativo de la serie ' || v_serie, 'registro', NULL);
    END IF;

    v_label_anterior := v_doc.serie || '-' || v_doc.numero;
    v_label_nuevo := v_serie || '-' || v_numero;

    IF v_numero::bigint IS DISTINCT FROM p_numero_esperado::bigint THEN
        RETURN json_build_object('error','El correlativo cambió durante la verificación. Vuelve a regularizar para comprobar el nuevo número.','registro',NULL);
    END IF;
    INSERT INTO ven_comprobante_historial_cpe
      (id_comprobante, serie, numero, datos_originales, verificacion_sunat, serie_nueva, numero_nuevo, fecha_emision_nueva, id_usuario_creacion)
    VALUES (p_id, v_doc.serie, v_doc.numero, to_jsonb(v_doc), p_verificacion, v_serie, v_numero, p_fecha_emision, p_id_usuario_auditoria);

    v_ref_anterior := ven_resolver_tipo_documento_ref(v_doc.codigo_tipo, v_doc.nombre_tipo_venta);
    v_ref_nuevo := ven_resolver_tipo_documento_ref(v_destino, v_doc.nombre_tipo_venta);

    IF v_ref_anterior <> v_ref_nuevo THEN
        SELECT lo.id INTO v_id_ref_anterior
        FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = v_ref_anterior AND lo.estado = 1
        LIMIT 1;
        SELECT lo.id INTO v_id_ref_nuevo
        FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = v_ref_nuevo AND lo.estado = 1
        LIMIT 1;

        IF v_id_ref_anterior IS NULL OR v_id_ref_nuevo IS NULL THEN
            RAISE EXCEPTION 'Tipo de documento de inventario % o % no configurado', v_ref_anterior, v_ref_nuevo;
        END IF;

        UPDATE inv_movimiento
        SET id_tipo_documento_origen = v_id_ref_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_documento_origen = p_id
          AND id_tipo_documento_origen = v_id_ref_anterior;
    END IF;

    UPDATE doc_salida_referencia
    SET id_tipo_comprobante = v_id_tipo_destino,
        serie = v_serie,
        numero = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE doc_salida
    SET observaciones = replace(observaciones, v_label_anterior, v_label_nuevo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_venta = p_id AND estado = 1
      AND observaciones LIKE '%' || v_label_anterior || '%';

    UPDATE fin_cuenta
    SET numero_comprobante = CASE WHEN numero_comprobante IS NULL THEN NULL ELSE v_label_nuevo END,
        descripcion = replace(descripcion, v_label_anterior, v_label_nuevo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_venta = p_id;

    UPDATE bal_baja_balon
    SET serie_comprobante = v_serie,
        numero_comprobante = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_venta = p_id;

    UPDATE bal_movimiento_recarga
    SET serie_factura = v_serie,
        numero_factura = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND serie_factura IS NOT NULL;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    UPDATE ven_comprobante
    SET id_tipo_comprobante = v_id_tipo_destino,
        serie = v_serie,
        numero = v_numero,
        fecha_emision_cpe = p_fecha_emision,
        id_estado_sunat = COALESCE(v_id_pendiente, id_estado_sunat),
        ticket_sunat = NULL,
        hash_documento = NULL,
        xml_firmado = NULL,
        cdr_respuesta = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object(
        'registro', json_build_object(
            'id', p_id,
            'codigo_tipo_comprobante', v_destino,
            'serie', v_serie,
            'numero', v_numero,
            'serie_anterior', v_doc.serie,
            'numero_anterior', v_doc.numero
        )
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_revertir_efectos_comprobante (
  p_id integer,
  p_id_usuario_auditoria integer,
  p_exigir_sin_pagos boolean
);

CREATE OR REPLACE FUNCTION public.ven_revertir_efectos_comprobante (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_exigir_sin_pagos boolean DEFAULT FALSE
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_hay_pagos BOOLEAN;
    v_codigo_tipo VARCHAR;
    v_nombre_tipo_venta VARCHAR;
    v_codigo_tipo_documento VARCHAR;
    v_rev_inv JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (SELECT 1 FROM ven_vsd_operacion WHERE id_comprobante=p_id AND tipo='CAMBIO_BALON' AND datos->>'tipoOperacion'='CAMBIO') THEN
        RAISE EXCEPTION 'El comprobante tiene cambios físicos registrados. La devolución comercial debe conciliar esos movimientos antes de revertir inventario';
    END IF;

    v_hay_pagos := fin_cuenta_documento_tiene_pagos(p_id, NULL);

    IF p_exigir_sin_pagos AND v_hay_pagos THEN
        RETURN json_build_object(
            'ok', FALSE,
            'error', 'No se puede eliminar: la cuenta por cobrar tiene pagos. Anule primero los pagos en Finanzas.'
        );
    END IF;

    SELECT
        tc.descripcion,
        COALESCE(tv.nombre, 'VENTA')
    INTO v_codigo_tipo, v_nombre_tipo_venta
    FROM ven_comprobante c
    INNER JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
    LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
    WHERE c.id = p_id AND c.estado = 1;

    v_codigo_tipo_documento := ven_resolver_tipo_documento_ref(v_codigo_tipo, v_nombre_tipo_venta);

    v_rev_inv := inv_revertir_por_documento(
        v_codigo_tipo_documento,
        p_id,
        p_id_usuario_auditoria
    );

    IF v_rev_inv->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_rev_inv->>'error';
    END IF;

    IF NOT v_hay_pagos THEN
        PERFORM fin_bajar_cuentas_documento(p_id_usuario_auditoria, p_id, NULL);
    END IF;

    PERFORM ven_cerrar_custodia_comprobante(p_id, p_id_usuario_auditoria);

    RETURN json_build_object('ok', TRUE, 'error', NULL);
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('ok', FALSE, 'error', SQLERRM);
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_validar_edicion_pre_emision (p_id integer);

CREATE OR REPLACE FUNCTION public.ven_validar_edicion_pre_emision (p_id integer) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE v_doc ven_comprobante%ROWTYPE; v_tipo text;
BEGIN
    IF NOT pg_try_advisory_xact_lock(872016,p_id) THEN
        RAISE EXCEPTION 'Hay una emisión en curso para este comprobante. Espere su resultado antes de editar';
    END IF;
    SELECT * INTO v_doc FROM ven_comprobante WHERE id=p_id AND estado=1 FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;
    SELECT descripcion INTO v_tipo FROM gen_lista_opciones WHERE id=v_doc.id_tipo_comprobante;
    IF v_tipo IN ('01','03') AND NOT ven_comprobante_permite_edicion(v_doc) THEN
        RAISE EXCEPTION 'La factura o boleta ya tiene una emisión, un envío por confirmar o documentos vinculados. Verifique su estado antes de corregir';
    END IF;
END;
$function$;

DROP FUNCTION IF EXISTS public.ven_cpe_validez_aceptada (c ven_comprobante);

CREATE OR REPLACE FUNCTION public.ven_cpe_validez_aceptada (c ven_comprobante) RETURNS boolean LANGUAGE sql STABLE AS $function$
  SELECT COALESCE(
    c.validez_sunat->>'codigo' = '1'
    AND c.validez_sunat->'consulta'->>'numeroSerie' = c.serie
    AND c.validez_sunat->'consulta'->'numero' = to_jsonb(CASE WHEN c.numero ~ '^[0-9]+$' THEN c.numero::numeric ELSE 0 END)
    AND c.validez_sunat->'consulta'->'monto' = to_jsonb(c.total_importe)
    AND c.validez_sunat->'consulta'->>'fechaEmision' = to_char(COALESCE(c.fecha_emision_cpe, c.fecha::date), 'DD/MM/YYYY')
    AND c.validez_sunat->'consulta'->>'codComp' = (SELECT descripcion FROM gen_lista_opciones WHERE id=c.id_tipo_comprobante), false);
$function$;

CREATE OR REPLACE TRIGGER ven_proteger_numeracion_nota_correccion
BEFORE UPDATE OF serie,
numero,
serie_original,
numero_original ON public.ven_cpe_correccion_nota FOR EACH ROW
EXECUTE FUNCTION public.ven_proteger_numeracion_nota_correccion ();

CREATE OR REPLACE TRIGGER ven_proteger_numeracion_correccion
BEFORE UPDATE OF serie,
numero,
id_tipo_comprobante ON public.ven_comprobante FOR EACH ROW
EXECUTE FUNCTION public.ven_proteger_numeracion_correccion ();

INSERT INTO
  gen_lista_opciones (id_lista, nombre, descripcion)
SELECT
  id,
  'CAMBIO_VSD',
  'Cambio físico de balón de venta sin documento'
FROM
  gen_lista
WHERE
  nombre = 'TipoDocumentoRef'
  AND NOT EXISTS (
    SELECT
      1
    FROM
      gen_lista_opciones
    WHERE
      id_lista = gen_lista.id
      AND nombre = 'CAMBIO_VSD'
  );

SELECT
  setval(
    'auth_permisos_id_seq',
    GREATEST(
      (
        SELECT
          MAX(id)
        FROM
          auth_permisos
      ),
      1
    )
  );

INSERT INTO
  auth_permisos (nombre, descripcion)
SELECT
  v.nombre,
  v.descripcion
FROM
  (
    VALUES
      ('actividades.crear', 'Crear actividades'),
      ('actividades.editar', 'Editar actividades'),
      ('actividades.eliminar', 'Eliminar actividades'),
      ('actividades.listar', 'Listar actividades'),
      ('actividades.ver', 'Ver detalle de actividades'),
      ('activo.crear', 'Crear activos'),
      ('activo.editar', 'Editar activos'),
      ('activo.eliminar', 'Eliminar activos'),
      ('activo.listar', 'Listar activos'),
      ('activo.ver', 'Ver detalle de activos'),
      (
        'catalogos.editar',
        'Editar catálogos (listas maestras)'
      ),
      ('choferes.crear', 'Crear choferes'),
      ('choferes.editar', 'Editar choferes'),
      ('choferes.eliminar', 'Eliminar choferes'),
      ('choferes.listar', 'Listar choferes'),
      ('choferes.ver', 'Ver detalle de choferes'),
      ('contactos.crear', 'Crear contactos de clientes'),
      (
        'contactos.editar',
        'Editar contactos de clientes'
      ),
      (
        'contactos.eliminar',
        'Eliminar contactos de clientes'
      ),
      (
        'contactos.listar',
        'Listar contactos de clientes'
      ),
      (
        'contactos.ver',
        'Ver detalle de contactos de clientes'
      ),
      (
        'cuentas_bancarias.crear',
        'Crear cuentas bancarias'
      ),
      (
        'cuentas_bancarias.editar',
        'Editar cuentas bancarias'
      ),
      (
        'cuentas_bancarias.eliminar',
        'Eliminar cuentas bancarias'
      ),
      (
        'cuentas_bancarias.listar',
        'Listar cuentas bancarias'
      ),
      (
        'cuentas_bancarias.ver',
        'Ver detalle de cuentas bancarias'
      ),
      (
        'dashboard.ver_compras',
        'Ver dashboard del módulo Compras'
      ),
      (
        'dashboard.ver_garantias',
        'Ver dashboard del módulo Garantías'
      ),
      (
        'dashboard.ver_productos',
        'Ver dashboard del módulo Productos'
      ),
      (
        'dashboard.ver_ventas',
        'Ver dashboard del módulo Ventas'
      ),
      (
        'direcciones.crear',
        'Crear direcciones de clientes'
      ),
      (
        'direcciones.editar',
        'Editar direcciones de clientes'
      ),
      (
        'direcciones.eliminar',
        'Eliminar direcciones de clientes'
      ),
      (
        'direcciones.listar',
        'Listar direcciones de clientes'
      ),
      (
        'direcciones.ver',
        'Ver detalle de direcciones de clientes'
      ),
      (
        'documentos_salida.crear',
        'Crear documentos de salida y agregar/quitar líneas'
      ),
      (
        'documentos_salida.editar',
        'Generar, editar detalle y registrar retorno de un documento de salida'
      ),
      (
        'documentos_salida.eliminar',
        'Anular un documento de salida'
      ),
      (
        'documentos_salida.emitir',
        'Convertir a guía de remisión y emitir/consultar estado SUNAT'
      ),
      (
        'documentos_salida.listar',
        'Listar documentos de salida (órdenes, recargas planta, guías)'
      ),
      (
        'documentos_salida.ver',
        'Ver detalle de un documento de salida'
      ),
      (
        'documentos_vencimiento.crear',
        'Crear permisos y certificados (vencimientos)'
      ),
      (
        'documentos_vencimiento.editar',
        'Editar permisos y certificados (vencimientos)'
      ),
      (
        'documentos_vencimiento.eliminar',
        'Eliminar permisos y certificados (vencimientos)'
      ),
      (
        'documentos_vencimiento.listar',
        'Listar permisos y certificados (vencimientos)'
      ),
      (
        'documentos_vencimiento.ver',
        'Ver detalle de permisos y certificados (vencimientos)'
      ),
      (
        'inventario_movimientos.crear',
        'Crear movimientos de inventario'
      ),
      (
        'inventario_movimientos.eliminar',
        'Eliminar movimientos de inventario'
      ),
      (
        'inventario_movimientos.listar',
        'Listar movimientos de inventario'
      ),
      (
        'inventario_movimientos.ver',
        'Ver detalle de movimientos de inventario'
      ),
      ('licencias.crear', 'Crear licencias de conducir'),
      (
        'licencias.editar',
        'Editar licencias de conducir'
      ),
      (
        'licencias.eliminar',
        'Eliminar licencias de conducir'
      ),
      (
        'licencias.listar',
        'Listar licencias de conducir'
      ),
      (
        'licencias.ver',
        'Ver detalle de licencias de conducir'
      ),
      ('trabajador.crear', 'Crear trabajadores'),
      ('trabajador.editar', 'Editar trabajadores'),
      ('trabajador.eliminar', 'Eliminar trabajadores'),
      ('trabajador.listar', 'Listar trabajadores'),
      ('trabajador.ver', 'Ver detalle de trabajadores'),
      ('vehiculos.crear', 'Crear vehículos'),
      ('vehiculos.editar', 'Editar vehículos'),
      ('vehiculos.eliminar', 'Eliminar vehículos'),
      ('vehiculos.listar', 'Listar vehículos'),
      ('vehiculos.ver', 'Ver detalle de vehículos')
  ) AS v (nombre, descripcion)
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      auth_permisos p
    WHERE
      p.nombre = v.nombre
  );

COMMIT;
