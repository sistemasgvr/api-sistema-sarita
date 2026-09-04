-- Table: ven_comprobante_pago
-- Escrita a mano en Fase 3 (pg_dump no disponible en el equipo). DDL espejo de
-- migraciones/20260904_f3_caja_medios_pago_cuentas.sql.
--
-- Cobro multi-medio de una venta: permite dividir un cobro entre efectivo y
-- transferencia, cada parte con su cuenta bancaria. `ven_comprobante.id_medio_pago`
-- queda como derivado de conveniencia (el medio de la línea de mayor monto), y
-- lo mantiene ven_sincronizar_pagos_comprobante, que es el único punto de
-- escritura de esta tabla.

CREATE TABLE ven_comprobante_pago (
    id integer NOT NULL,
    id_comprobante integer NOT NULL,
    item integer DEFAULT 1 NOT NULL,
    id_medio_pago integer NOT NULL,
    id_cuenta_bancaria integer,
    monto numeric(12,4) NOT NULL,
    numero_operacion character varying(80),
    referencia character varying(150),
    observacion character varying(500),
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    CONSTRAINT ven_comprobante_pago_monto_check CHECK ((monto > (0)::numeric))
);

CREATE SEQUENCE ven_comprobante_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE ven_comprobante_pago_id_seq OWNED BY public.ven_comprobante_pago.id;

ALTER TABLE ven_comprobante_pago ALTER COLUMN id SET DEFAULT nextval('public.ven_comprobante_pago_id_seq'::regclass);

ALTER TABLE ven_comprobante_pago
    ADD CONSTRAINT ven_comprobante_pago_pkey PRIMARY KEY (id);

CREATE INDEX idx_ven_comprobante_pago_comprobante ON ven_comprobante_pago USING btree (id_comprobante) WHERE (estado = 1);

CREATE INDEX idx_ven_comprobante_pago_cuenta ON ven_comprobante_pago USING btree (id_cuenta_bancaria) WHERE (estado = 1);

ALTER TABLE ven_comprobante_pago
    ADD CONSTRAINT ven_comprobante_pago_id_comprobante_fkey FOREIGN KEY (id_comprobante) REFERENCES public.ven_comprobante(id);

ALTER TABLE ven_comprobante_pago
    ADD CONSTRAINT ven_comprobante_pago_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE ven_comprobante_pago
    ADD CONSTRAINT ven_comprobante_pago_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria(id);

ALTER TABLE ven_comprobante_pago
    ADD CONSTRAINT ven_comprobante_pago_id_usuario_creacion_fkey FOREIGN KEY (id_usuario_creacion) REFERENCES public.auth_usuarios(id);

ALTER TABLE ven_comprobante_pago
    ADD CONSTRAINT ven_comprobante_pago_id_usuario_modificacion_fkey FOREIGN KEY (id_usuario_modificacion) REFERENCES public.auth_usuarios(id);
