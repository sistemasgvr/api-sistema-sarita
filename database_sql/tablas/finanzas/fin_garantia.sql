-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: fin_garantia
-- Generated: 2026-09-02T21:45:57.659Z

CREATE TABLE fin_garantia (
    id integer NOT NULL,
    fecha date NOT NULL,
    id_cliente integer NOT NULL,
    id_medio_pago integer,
    importe numeric(12,4) NOT NULL,
    observacion character varying(500),
    id_estado integer,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    fecha_reembolso date,
    id_medio_reembolso integer,
    observacion_reembolso character varying(500),
    id_usuario_reembolso integer,
    CONSTRAINT fin_garantia_importe_positivo CHECK ((importe > (0)::numeric))
);

CREATE SEQUENCE fin_garantia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE fin_garantia_id_seq OWNED BY public.fin_garantia.id;

ALTER TABLE fin_garantia ALTER COLUMN id SET DEFAULT nextval('public.fin_garantia_id_seq'::regclass);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_pkey PRIMARY KEY (id);

CREATE INDEX idx_fin_garantia_cliente_fecha ON fin_garantia USING btree (id_cliente, fecha DESC);

CREATE INDEX idx_fin_garantia_estado ON fin_garantia USING btree (estado);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_cliente_fkey FOREIGN KEY (id_cliente) REFERENCES public.cli_clientes(id);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_medio_reembolso_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_medio_reembolso_fkey1 FOREIGN KEY (id_medio_reembolso) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE fin_garantia
    ADD CONSTRAINT fin_garantia_id_usuario_reembolso_fkey FOREIGN KEY (id_usuario_reembolso) REFERENCES public.auth_usuarios(id);
