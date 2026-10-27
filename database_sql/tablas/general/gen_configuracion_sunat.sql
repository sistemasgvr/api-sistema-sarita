-- Configuración SUNAT y del proveedor de facturación electrónica por empresa
CREATE TABLE public.gen_configuracion_sunat (
  id integer NOT NULL,
  id_empresa integer NOT NULL,
  usuario_sol character varying(50),
  clave_sol character varying(255),
  certificado_digital character varying(255),
  clave_certificado character varying(255),
  id_ambiente integer,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  apisperu_habilitado boolean DEFAULT TRUE,
  apisperu_url character varying(255),
  apisperu_token text,
  apisperu_timeout_ms integer DEFAULT 60000,
  client_id_gre character varying(255),
  client_secret_gre character varying(255),
  proveedor_pse character varying(50) DEFAULT NULL::character varying,
  pse_habilitado boolean DEFAULT TRUE NOT NULL,
  api_base_url character varying(255) DEFAULT NULL::character varying,
  api_token text,
  api_usuario character varying(150) DEFAULT NULL::character varying,
  api_clave character varying(255) DEFAULT NULL::character varying,
  ruc_emisor character varying(11) DEFAULT NULL::character varying,
  client_id character varying(255) DEFAULT NULL::character varying,
  client_secret character varying(255) DEFAULT NULL::character varying,
  timeout_ms integer,
  validez_client_id character varying(255),
  validez_client_secret character varying(255)
);

COMMENT ON COLUMN public.gen_configuracion_sunat.proveedor_pse IS 'Código del PSE/OSE (ej. APISPERU). Orientativo.';

COMMENT ON COLUMN public.gen_configuracion_sunat.api_base_url IS 'URL base del API de facturación electrónica';

COMMENT ON COLUMN public.gen_configuracion_sunat.api_token IS 'Token Bearer / API key del PSE (cifrar en app)';

COMMENT ON COLUMN public.gen_configuracion_sunat.client_id IS 'OAuth client_id (ej. GRE SUNAT CPE)';

COMMENT ON COLUMN public.gen_configuracion_sunat.client_secret IS 'OAuth client_secret (cifrar en app)';

COMMENT ON COLUMN public.gen_configuracion_sunat.validez_client_id IS 'Client ID de consulta integrada de validez CPE (no GRE)';

COMMENT ON COLUMN public.gen_configuracion_sunat.validez_client_secret IS 'Client Secret de consulta integrada de validez CPE; no exponer por HTTP';

CREATE SEQUENCE public.gen_configuracion_sunat_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.gen_configuracion_sunat_id_seq OWNED BY public.gen_configuracion_sunat.id;

ALTER TABLE ONLY public.gen_configuracion_sunat
ALTER COLUMN id
SET DEFAULT nextval('public.gen_configuracion_sunat_id_seq'::regclass);

ALTER TABLE ONLY public.gen_configuracion_sunat
ADD CONSTRAINT gen_configuracion_sunat_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.gen_configuracion_sunat
ADD CONSTRAINT gen_configuracion_sunat_id_ambiente_fkey FOREIGN KEY (id_ambiente) REFERENCES public.gen_lista_opciones (id);

ALTER TABLE ONLY public.gen_configuracion_sunat
ADD CONSTRAINT gen_configuracion_sunat_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa (id);

ALTER TABLE ONLY public.gen_configuracion_sunat
ADD CONSTRAINT gen_configuracion_sunat_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios (id);

ALTER TABLE ONLY public.gen_configuracion_sunat
ADD CONSTRAINT gen_configuracion_sunat_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios (id);
