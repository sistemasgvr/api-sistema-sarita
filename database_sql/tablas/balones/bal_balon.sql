-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js
-- Table: bal_balon
-- Generated: 2026-09-02T21:42:18.699Z

CREATE TABLE bal_balon (
    id integer NOT NULL,
    codigo_balon character varying(50) NOT NULL,
    libro_cilindro character varying(30),
    pagina_libro integer,
    fecha_registro date,
    id_almacen integer,
    id_cliente_ubicacion integer,
    id_propietario integer,
    id_cliente_propietario integer,
    id_referencia integer,
    id_tipo_balon integer NOT NULL,
    id_producto_gas integer,
    id_estado_balon integer,
    fecha_ultima_prueba_hidrostatica date,
    vigencia_prueba_hidrostatica_anios integer DEFAULT 5,
    fecha_proxima_prueba_hidrostatica date,
    fecha_fabricacion date,
    numero_recepcion character varying(30),
    presion_actual numeric(8,2),
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    numero_serie character varying(50),
    id_marca_cilindro integer,
    id_organo_inspector integer,
    organo_inspector_no_aplica boolean DEFAULT false NOT NULL,
    anio_fabricacion smallint,
    mes_fabricacion smallint,
    id_planta integer,
    tipo_valvula character varying(100),
    peso_aproximado_kg numeric(10,4),
    sello_inspeccion character varying(100)
);

CREATE SEQUENCE bal_balon_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE bal_balon_id_seq OWNED BY public.bal_balon.id;

ALTER TABLE bal_balon ALTER COLUMN id SET DEFAULT nextval('public.bal_balon_id_seq'::regclass);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_codigo_balon_key UNIQUE (codigo_balon);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_pkey PRIMARY KEY (id);

CREATE INDEX idx_bal_balon_anio_fabricacion ON bal_balon USING btree (anio_fabricacion);

CREATE INDEX idx_bal_balon_cliente ON bal_balon USING btree (id_cliente_propietario);

CREATE INDEX idx_bal_balon_cliente_ubic ON bal_balon USING btree (id_cliente_ubicacion);

CREATE INDEX idx_bal_balon_codigo ON bal_balon USING btree (codigo_balon);

CREATE INDEX idx_bal_balon_estado ON bal_balon USING btree (id_estado_balon);

CREATE INDEX idx_bal_balon_libro ON bal_balon USING btree (libro_cilindro, pagina_libro);

CREATE INDEX idx_bal_balon_marca ON bal_balon USING btree (id_marca_cilindro);

CREATE INDEX idx_bal_balon_mes_anio_fab ON bal_balon USING btree (anio_fabricacion, mes_fabricacion) WHERE (estado = 1);

CREATE INDEX idx_bal_balon_numero_serie ON bal_balon USING btree (numero_serie);

CREATE INDEX idx_bal_balon_ph_vence ON bal_balon USING btree (fecha_proxima_prueba_hidrostatica);

CREATE INDEX idx_bal_balon_planta ON bal_balon USING btree (id_planta) WHERE (id_planta IS NOT NULL);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_almacen_fkey FOREIGN KEY (id_almacen) REFERENCES public.gen_almacen(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_cliente_propietario_fkey FOREIGN KEY (id_cliente_propietario) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_cliente_ubicacion_fkey FOREIGN KEY (id_cliente_ubicacion) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_estado_balon_fkey FOREIGN KEY (id_estado_balon) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_marca_cilindro_fkey FOREIGN KEY (id_marca_cilindro) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_organo_inspector_fkey FOREIGN KEY (id_organo_inspector) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_planta_fkey FOREIGN KEY (id_planta) REFERENCES public.cli_clientes(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_producto_gas_fkey FOREIGN KEY (id_producto_gas) REFERENCES public.pro_producto(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_propietario_fkey FOREIGN KEY (id_propietario) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_referencia_fkey FOREIGN KEY (id_referencia) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_tipo_balon_fkey FOREIGN KEY (id_tipo_balon) REFERENCES public.bal_tipo_balon(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE bal_balon
    ADD CONSTRAINT bal_balon_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
