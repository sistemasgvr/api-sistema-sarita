-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: gen_documento_vencimiento
-- Generated: 2026-09-02T21:47:38.098Z

CREATE TABLE gen_documento_vencimiento (
    id integer NOT NULL,
    id_categoria integer,
    descripcion character varying(255) NOT NULL,
    id_vehiculo integer,
    fecha_vencimiento date NOT NULL,
    fecha_renovacion date,
    numero_documento character varying(50),
    observacion character varying(255),
    id_estado integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_sucursal integer
);

CREATE SEQUENCE gen_documento_vencimiento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE gen_documento_vencimiento_id_seq OWNED BY public.gen_documento_vencimiento.id;

ALTER TABLE gen_documento_vencimiento ALTER COLUMN id SET DEFAULT nextval('public.gen_documento_vencimiento_id_seq'::regclass);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_pkey PRIMARY KEY (id);

CREATE INDEX idx_gen_doc_vencimiento_fecha ON gen_documento_vencimiento USING btree (fecha_vencimiento);

CREATE INDEX idx_gen_doc_vencimiento_vehiculo ON gen_documento_vencimiento USING btree (id_vehiculo);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE gen_documento_vencimiento
    ADD CONSTRAINT gen_documento_vencimiento_id_vehiculo_fkey FOREIGN KEY (id_vehiculo) REFERENCES public.gen_vehiculo(id);
