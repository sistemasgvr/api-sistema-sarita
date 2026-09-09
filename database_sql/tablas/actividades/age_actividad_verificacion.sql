-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: age_actividad_verificacion
-- Generated: 2026-09-09T16:17:05.373Z
CREATE TABLE age_actividad_verificacion (
    id integer NOT NULL,
    id_actividad integer NOT NULL,
    id_actividad_item integer,
    momento character varying(10) NOT NULL,
    codigo_escaneado character varying(60) NOT NULL,
    coincide boolean DEFAULT false NOT NULL,
    observacion character varying(500),
    fecha timestamp without time zone DEFAULT now(),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    CONSTRAINT chk_age_verif_momento CHECK (((momento)::text = ANY ((ARRAY['SALIDA'::character varying, 'LLEGADA'::character varying])::text[])))
);

CREATE SEQUENCE age_actividad_verificacion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE age_actividad_verificacion_id_seq OWNED BY public.age_actividad_verificacion.id;

ALTER TABLE age_actividad_verificacion ALTER COLUMN id SET DEFAULT nextval('public.age_actividad_verificacion_id_seq'::regclass);

ALTER TABLE age_actividad_verificacion
    ADD CONSTRAINT age_actividad_verificacion_pkey PRIMARY KEY (id);

CREATE INDEX idx_age_verif_actividad ON age_actividad_verificacion USING btree (id_actividad);

CREATE INDEX idx_age_verif_item ON age_actividad_verificacion USING btree (id_actividad_item);

ALTER TABLE age_actividad_verificacion
    ADD CONSTRAINT age_actividad_verificacion_id_actividad_fkey FOREIGN KEY (id_actividad) REFERENCES public.age_actividad(id);

ALTER TABLE age_actividad_verificacion
    ADD CONSTRAINT age_actividad_verificacion_id_actividad_item_fkey FOREIGN KEY (id_actividad_item) REFERENCES public.age_actividad_item(id);

ALTER TABLE age_actividad_verificacion
    ADD CONSTRAINT age_actividad_verificacion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE age_actividad_verificacion
    ADD CONSTRAINT age_actividad_verificacion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
