-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: tra_trabajadores
-- Generated: 2026-09-02T21:50:34.367Z

CREATE TABLE tra_trabajadores (
    id integer NOT NULL,
    nombres character varying(150) NOT NULL,
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    id_tipo_documento integer,
    numero_documento character varying(20),
    direccion character varying(255),
    referencia character varying(255),
    latitud numeric(10,8),
    longitud numeric(11,8),
    id_pais integer,
    id_departamento integer,
    id_provincia integer,
    id_distrito integer,
    fecha_nacimiento date,
    fecha_inicio date,
    fecha_cese date,
    id_area integer,
    id_cargo integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    correo character varying(150)
);

CREATE SEQUENCE tra_trabajadores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE tra_trabajadores_id_seq OWNED BY public.tra_trabajadores.id;

ALTER TABLE tra_trabajadores ALTER COLUMN id SET DEFAULT nextval('public.tra_trabajadores_id_seq'::regclass);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_pkey PRIMARY KEY (id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_area_fkey FOREIGN KEY (id_area) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_cargo_fkey FOREIGN KEY (id_cargo) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.gen_departamento(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_distrito_fkey FOREIGN KEY (id_distrito) REFERENCES public.gen_distrito(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_pais_fkey FOREIGN KEY (id_pais) REFERENCES public.gen_pais(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_provincia_fkey FOREIGN KEY (id_provincia) REFERENCES public.gen_provincia(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_tipo_documento_fkey FOREIGN KEY (id_tipo_documento) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE tra_trabajadores
    ADD CONSTRAINT tra_trabajadores_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
