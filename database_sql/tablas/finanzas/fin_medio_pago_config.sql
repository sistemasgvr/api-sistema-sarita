-- Table: fin_medio_pago_config
-- Escrita a mano en Fase 3 (pg_dump no disponible en el equipo). DDL espejo de
-- migraciones/20260904_f3_caja_medios_pago_cuentas.sql.
--
-- Fuente única del comportamiento de cada medio de pago. Sustituye a los
-- `UPPER(mp.nombre) IN ('EFECTIVO','YAPE','PLIN')` que estaban repartidos por
-- las funciones de caja. Se lee mediante fin_medio_pago_flag(), que lanza
-- excepción si el medio no está configurado (mismo criterio que
-- inv_signo_tipo_movimiento en Fase 1).
--
-- Los valores iniciales están en seeds/fin_medio_pago_config.sql.

CREATE TABLE fin_medio_pago_config (
    id_medio_pago integer NOT NULL,
    es_efectivo boolean DEFAULT false NOT NULL,
    afecta_caja boolean DEFAULT false NOT NULL,
    requiere_cuenta_bancaria boolean DEFAULT false NOT NULL,
    requiere_numero_operacion boolean DEFAULT false NOT NULL,
    es_credito boolean DEFAULT false NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now(),
    CONSTRAINT fin_medio_pago_config_coherente CHECK ((NOT ((es_efectivo OR es_credito) AND requiere_cuenta_bancaria)))
);

ALTER TABLE fin_medio_pago_config
    ADD CONSTRAINT fin_medio_pago_config_pkey PRIMARY KEY (id_medio_pago);

ALTER TABLE fin_medio_pago_config
    ADD CONSTRAINT fin_medio_pago_config_id_medio_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);
