-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_tipo_balon
-- Generated: 2026-09-02T21:44:16.152Z

CREATE TABLE bal_tipo_balon (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    id_gas integer,
    capacidad numeric(10,4),
    id_unidad_medida integer,
    peso numeric(10,4),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    vigencia_ph_anios integer DEFAULT 5 NOT NULL,
    capacidad_lb numeric(12,4),
    presion_llenado_psi numeric(12,2),
    peso_tara_lb numeric(12,4)
);

CREATE SEQUENCE bal_tipo_balon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_tipo_balon_id_seq OWNED BY public.bal_tipo_balon.id;

ALTER TABLE bal_tipo_balon ALTER COLUMN id SET DEFAULT nextval('public.bal_tipo_balon_id_seq'::regclass);

ALTER TABLE bal_tipo_balon
    ADD CONSTRAINT bal_tipo_balon_pkey PRIMARY KEY (id);

ALTER TABLE bal_tipo_balon
    ADD CONSTRAINT bal_tipo_balon_id_gas_fkey FOREIGN KEY (id_gas) REFERENCES public.pro_producto(id);

ALTER TABLE bal_tipo_balon
    ADD CONSTRAINT bal_tipo_balon_id_unidad_medida_fkey FOREIGN KEY (id_unidad_medida) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_tipo_balon
    ADD CONSTRAINT bal_tipo_balon_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_tipo_balon
    ADD CONSTRAINT bal_tipo_balon_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
