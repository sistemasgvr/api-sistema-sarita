-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: doc_rango_numeracion
-- Generated: 2026-09-03T16:49:08.981Z

CREATE TABLE doc_rango_numeracion (
    id integer NOT NULL,
    responsable character varying(150) NOT NULL,
    descripcion character varying(255),
    serie character varying(10),
    numero_inicio integer NOT NULL,
    numero_fin integer NOT NULL,
    numero_actual integer,
    fecha_asignacion date,
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now() NOT NULL,
    fecha_modificacion timestamp without time zone
);

CREATE SEQUENCE doc_rango_numeracion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE doc_rango_numeracion_id_seq OWNED BY public.doc_rango_numeracion.id;

ALTER TABLE doc_rango_numeracion ALTER COLUMN id SET DEFAULT nextval('public.doc_rango_numeracion_id_seq'::regclass);

ALTER TABLE doc_rango_numeracion
    ADD CONSTRAINT doc_rango_numeracion_pkey PRIMARY KEY (id);

ALTER TABLE doc_rango_numeracion
    ADD CONSTRAINT doc_rango_numeracion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE doc_rango_numeracion
    ADD CONSTRAINT doc_rango_numeracion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
