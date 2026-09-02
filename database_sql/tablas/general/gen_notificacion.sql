-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_notificacion
-- Generated: 2026-09-02T21:48:19.950Z

CREATE TABLE gen_notificacion (
    id integer NOT NULL,
    id_usuario integer NOT NULL,
    codigo_tipo character varying(50) NOT NULL,
    titulo character varying(200) NOT NULL,
    mensaje text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    id_referencia integer,
    tipo_referencia character varying(50),
    clave_dedupe character varying(160),
    leida boolean DEFAULT false NOT NULL,
    fecha_lectura timestamp without time zone,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gen_notificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_notificacion_id_seq OWNED BY public.gen_notificacion.id;

ALTER TABLE gen_notificacion ALTER COLUMN id SET DEFAULT nextval('public.gen_notificacion_id_seq'::regclass);

ALTER TABLE gen_notificacion
    ADD CONSTRAINT gen_notificacion_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_notificacion_usuario_leida ON gen_notificacion USING btree (id_usuario, leida, fecha_creacion DESC) WHERE (estado = 1);

CREATE UNIQUE INDEX uq_gen_notificacion_dedupe ON gen_notificacion USING btree (id_usuario, clave_dedupe) WHERE ((estado = 1) AND (clave_dedupe IS NOT NULL));

ALTER TABLE gen_notificacion
    ADD CONSTRAINT gen_notificacion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_notificacion
    ADD CONSTRAINT gen_notificacion_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_notificacion
    ADD CONSTRAINT gen_notificacion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
