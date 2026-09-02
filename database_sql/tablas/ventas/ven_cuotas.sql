-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: ven_cuotas
-- Generated: 2026-09-02T21:50:59.567Z

CREATE TABLE ven_cuotas (
    id integer NOT NULL,
    id_comprobante integer NOT NULL,
    numero_cuota integer NOT NULL,
    fecha_vencimiento date NOT NULL,
    monto numeric(12,4) NOT NULL,
    monto_pagado numeric(12,4) DEFAULT 0,
    id_estado integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE ven_cuotas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_cuotas_id_seq OWNED BY public.ven_cuotas.id;

ALTER TABLE ven_cuotas ALTER COLUMN id SET DEFAULT nextval('public.ven_cuotas_id_seq'::regclass);

ALTER TABLE ven_cuotas
    ADD CONSTRAINT ven_cuotas_pkey PRIMARY KEY (id);

ALTER TABLE ven_cuotas
    ADD CONSTRAINT ven_cuotas_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE ven_cuotas
    ADD CONSTRAINT ven_cuotas_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_cuotas
    ADD CONSTRAINT ven_cuotas_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_cuotas
    ADD CONSTRAINT ven_cuotas_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
