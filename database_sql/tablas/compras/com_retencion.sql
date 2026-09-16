CREATE TABLE com_retencion (
    id integer NOT NULL,
    serie character varying(10) NOT NULL,
    numero character varying(15) NOT NULL,
    fecha_emision date NOT NULL,
    id_empresa integer NOT NULL,
    id_proveedor integer NOT NULL,
    id_sucursal integer,
    regimen character varying(5) NOT NULL,
    tasa numeric(8,4) NOT NULL,
    base_imponible numeric(12,4) DEFAULT 0 NOT NULL,
    monto_retenido numeric(12,4) DEFAULT 0 NOT NULL,
    monto_pagado numeric(12,4) DEFAULT 0 NOT NULL,
    observacion character varying(500),
    id_estado_sunat integer,
    ticket_sunat character varying(100),
    hash_documento character varying(100),
    xml_firmado text,
    cdr_respuesta text,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE com_retencion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE com_retencion_id_seq OWNED BY public.com_retencion.id;

ALTER TABLE com_retencion ALTER COLUMN id SET DEFAULT nextval('public.com_retencion_id_seq'::regclass);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_pkey PRIMARY KEY (id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_empresa_serie_numero_key UNIQUE (id_empresa, serie, numero);

CREATE INDEX idx_com_retencion_empresa ON com_retencion USING btree (id_empresa);

CREATE INDEX idx_com_retencion_proveedor ON com_retencion USING btree (id_proveedor);

CREATE INDEX idx_com_retencion_fecha ON com_retencion USING btree (fecha_emision);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_empresa_fkey FOREIGN KEY (id_empresa) REFERENCES public.gen_empresa(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_proveedor_fkey FOREIGN KEY (id_proveedor) REFERENCES public.cli_clientes(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_sucursal_fkey FOREIGN KEY (id_sucursal) REFERENCES public.gen_sucursal(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_estado_sunat_fkey FOREIGN KEY (id_estado_sunat) REFERENCES public.gen_lista_opciones(id);


ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE com_retencion ADD CONSTRAINT com_retencion_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
