-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_licencia
-- Generated: 2026-09-02T21:47:54.886Z

CREATE TABLE gen_licencia (
    id integer NOT NULL,
    id_tipo_licencia integer,
    id_categoria_licencia integer,
    id_chofer integer,
    codigo character varying(20) NOT NULL,
    fecha_emision date NOT NULL,
    fecha_vencimiento date NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_licencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_licencia_id_seq OWNED BY public.gen_licencia.id;

ALTER TABLE gen_licencia ALTER COLUMN id SET DEFAULT nextval('public.gen_licencia_id_seq'::regclass);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_codigo_key UNIQUE (codigo);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_pkey PRIMARY KEY (id);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_id_categoria_licencia_fkey FOREIGN KEY (id_categoria_licencia) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_id_chofer_fkey FOREIGN KEY (id_chofer) REFERENCES public.gen_chofer(id);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_id_tipo_licencia_fkey FOREIGN KEY (id_tipo_licencia) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_licencia
    ADD CONSTRAINT gen_licencia_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
