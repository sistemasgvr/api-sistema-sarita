-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: cli_baja_cliente
-- Generated: 2026-09-02T21:44:24.700Z

CREATE TABLE cli_baja_cliente (
    id integer NOT NULL,
    id_cliente integer NOT NULL,
    id_motivo_baja integer,
    fecha_baja date DEFAULT CURRENT_DATE,
    id_usuario_solicita integer NOT NULL,
    id_usuario_autoriza integer,
    fecha_autorizacion timestamp without time zone,
    id_estado_aprobacion integer,
    motivo_detalle character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    id_tipo_solicitud integer
);

CREATE SEQUENCE cli_baja_cliente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE cli_baja_cliente_id_seq OWNED BY public.cli_baja_cliente.id;

ALTER TABLE cli_baja_cliente ALTER COLUMN id SET DEFAULT nextval('public.cli_baja_cliente_id_seq'::regclass);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_pkey PRIMARY KEY (id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_estado_aprobacion_fkey FOREIGN KEY (id_estado_aprobacion) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_motivo_baja_fkey FOREIGN KEY (id_motivo_baja) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_tipo_solicitud_fkey FOREIGN KEY (id_tipo_solicitud) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_usuario_autoriza_fkey FOREIGN KEY (id_usuario_autoriza) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE cli_baja_cliente
    ADD CONSTRAINT cli_baja_cliente_id_usuario_solicita_fkey FOREIGN KEY (id_usuario_solicita) REFERENCES public.auth_usuarios(id);
