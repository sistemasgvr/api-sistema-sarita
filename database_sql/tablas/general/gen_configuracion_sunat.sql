-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_configuracion_sunat
-- Generated: 2026-09-02T21:47:04.482Z

CREATE TABLE gen_configuracion_sunat (
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
    apisperu_habilitado boolean DEFAULT true,
    apisperu_url character varying(255),
    apisperu_token text,
    apisperu_timeout_ms integer DEFAULT 60000,
    client_id_gre character varying(255),
    client_secret_gre character varying(255),
    proveedor_pse character varying(50) DEFAULT NULL::character varying,
    pse_habilitado boolean DEFAULT true NOT NULL,
    api_base_url character varying(255) DEFAULT NULL::character varying,
    api_token text,
    api_usuario character varying(150) DEFAULT NULL::character varying,
    api_clave character varying(255) DEFAULT NULL::character varying,
    ruc_emisor character varying(11) DEFAULT NULL::character varying,
    client_id character varying(255) DEFAULT NULL::character varying,
    client_secret character varying(255) DEFAULT NULL::character varying,
    timeout_ms integer
);

CREATE SEQUENCE gen_configuracion_sunat_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_configuracion_sunat_id_seq OWNED BY public.gen_configuracion_sunat.id;

ALTER TABLE gen_configuracion_sunat ALTER COLUMN id SET DEFAULT nextval('public.gen_configuracion_sunat_id_seq'::regclass);

ALTER TABLE gen_configuracion_sunat
    ADD CONSTRAINT gen_configuracion_sunat_pkey PRIMARY KEY (id);

ALTER TABLE gen_configuracion_sunat
    ADD CONSTRAINT gen_configuracion_sunat_id_ambiente_fkey FOREIGN KEY (id_ambiente) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_configuracion_sunat
    ADD CONSTRAINT gen_configuracion_sunat_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE gen_configuracion_sunat
    ADD CONSTRAINT gen_configuracion_sunat_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_configuracion_sunat
    ADD CONSTRAINT gen_configuracion_sunat_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
