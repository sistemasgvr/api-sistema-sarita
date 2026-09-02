-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gre_rango_numeracion
-- Generated: 2026-09-02T21:49:26.964Z

CREATE TABLE gre_rango_numeracion (
    id integer NOT NULL,
    responsable character varying(100) NOT NULL,
    descripcion character varying(150),
    serie character varying(10),
    numero_inicio integer NOT NULL,
    numero_fin integer NOT NULL,
    numero_actual integer,
    fecha_asignacion date,
    observacion character varying(255),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE gre_rango_numeracion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gre_rango_numeracion_id_seq OWNED BY public.gre_rango_numeracion.id;

ALTER TABLE gre_rango_numeracion ALTER COLUMN id SET DEFAULT nextval('public.gre_rango_numeracion_id_seq'::regclass);

ALTER TABLE gre_rango_numeracion
    ADD CONSTRAINT gre_rango_numeracion_pkey PRIMARY KEY (id);

CREATE INDEX idx_gre_rango_responsable ON gre_rango_numeracion USING btree (responsable);

ALTER TABLE gre_rango_numeracion
    ADD CONSTRAINT gre_rango_numeracion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gre_rango_numeracion
    ADD CONSTRAINT gre_rango_numeracion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
