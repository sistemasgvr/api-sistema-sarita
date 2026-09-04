-- =============================================================================
-- Fase 3 — Caja, medios de pago y cuentas bancarias
-- =============================================================================
-- Solo DDL + catálogos. Los cuerpos de función viven en database_sql/funciones/
-- y se aplican con: node database_sql/scripts/rebuild-schema-from-repo.js --functions
--
-- Decisiones tomadas (plan §5, puntos 6 y 7):
--   * Cuenta bancaria ↔ medio de pago es N:M  -> tabla puente gen_cuenta_medio_pago.
--   * Las cuentas de EMPRESA se comparten entre sucursales (sin id_sucursal):
--     la sucursal ya queda registrada en el movimiento que usa la cuenta.
--   * El historial de caja lleva todas las pestañas de caja.
--
-- Idempotente: se puede reejecutar.
-- =============================================================================

SET TIME ZONE 'America/Lima';

-- -----------------------------------------------------------------------------
-- 1. gen_cuenta_bancaria: ámbito CLIENTE | EMPRESA
-- -----------------------------------------------------------------------------
-- Hasta ahora la tabla era exclusivamente de cuentas de cliente. Las filas con
-- id_cliente NULL se distinguían con el hack `p_id_cliente = -1` en el listado.
-- El ámbito lo vuelve explícito.

ALTER TABLE gen_cuenta_bancaria
    ADD COLUMN IF NOT EXISTS ambito character varying(10);

ALTER TABLE gen_cuenta_bancaria
    ADD COLUMN IF NOT EXISTS alias character varying(100);

ALTER TABLE gen_cuenta_bancaria
    ADD COLUMN IF NOT EXISTS id_empresa integer;

-- Backfill: con cliente = cuenta de cliente; sin cliente = cuenta de la empresa.
UPDATE gen_cuenta_bancaria
SET ambito = CASE WHEN id_cliente IS NOT NULL THEN 'CLIENTE' ELSE 'EMPRESA' END
WHERE ambito IS NULL;

UPDATE gen_cuenta_bancaria
SET id_empresa = (SELECT MIN(id) FROM gen_empresa WHERE estado = 1)
WHERE ambito = 'EMPRESA'
  AND id_empresa IS NULL
  AND EXISTS (SELECT 1 FROM gen_empresa WHERE estado = 1);

ALTER TABLE gen_cuenta_bancaria
    ALTER COLUMN ambito SET DEFAULT 'CLIENTE';

ALTER TABLE gen_cuenta_bancaria
    ALTER COLUMN ambito SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_bancaria_ambito_check'
    ) THEN
        ALTER TABLE gen_cuenta_bancaria
            ADD CONSTRAINT gen_cuenta_bancaria_ambito_check
            CHECK (ambito IN ('CLIENTE', 'EMPRESA'));
    END IF;

    -- Una cuenta de cliente exige cliente; una de empresa no puede tenerlo.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_bancaria_ambito_coherente'
    ) THEN
        ALTER TABLE gen_cuenta_bancaria
            ADD CONSTRAINT gen_cuenta_bancaria_ambito_coherente
            CHECK (
                (ambito = 'CLIENTE' AND id_cliente IS NOT NULL)
                OR (ambito = 'EMPRESA' AND id_cliente IS NULL)
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_bancaria_id_empresa_fkey'
    ) THEN
        ALTER TABLE gen_cuenta_bancaria
            ADD CONSTRAINT gen_cuenta_bancaria_id_empresa_fkey
            FOREIGN KEY (id_empresa) REFERENCES gen_empresa(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_gen_cuenta_ambito
    ON gen_cuenta_bancaria USING btree (ambito) WHERE estado = 1;

-- -----------------------------------------------------------------------------
-- 2. gen_cuenta_medio_pago — puente N:M cuenta de empresa ↔ medio de pago
-- -----------------------------------------------------------------------------
-- Una misma cuenta puede recibir varios medios (p. ej. la cuenta BCP que recibe
-- transferencia y además tiene Yape asociado al mismo titular).

CREATE TABLE IF NOT EXISTS gen_cuenta_medio_pago (
    id integer NOT NULL,
    id_cuenta_bancaria integer NOT NULL,
    id_medio_pago integer NOT NULL,
    es_predeterminada boolean DEFAULT false NOT NULL,
    estado integer DEFAULT 1 NOT NULL,
    id_usuario_creacion integer,
    id_usuario_modificacion integer,
    fecha_creacion timestamp without time zone DEFAULT now(),
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS gen_cuenta_medio_pago_id_seq
    AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE gen_cuenta_medio_pago_id_seq OWNED BY public.gen_cuenta_medio_pago.id;

ALTER TABLE gen_cuenta_medio_pago
    ALTER COLUMN id SET DEFAULT nextval('public.gen_cuenta_medio_pago_id_seq'::regclass);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_medio_pago_pkey') THEN
        ALTER TABLE gen_cuenta_medio_pago ADD CONSTRAINT gen_cuenta_medio_pago_pkey PRIMARY KEY (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_medio_pago_id_cuenta_fkey') THEN
        ALTER TABLE gen_cuenta_medio_pago
            ADD CONSTRAINT gen_cuenta_medio_pago_id_cuenta_fkey
            FOREIGN KEY (id_cuenta_bancaria) REFERENCES gen_cuenta_bancaria(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_medio_pago_id_medio_fkey') THEN
        ALTER TABLE gen_cuenta_medio_pago
            ADD CONSTRAINT gen_cuenta_medio_pago_id_medio_fkey
            FOREIGN KEY (id_medio_pago) REFERENCES gen_lista_opciones(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_medio_pago_id_usuario_creacion_fkey') THEN
        ALTER TABLE gen_cuenta_medio_pago
            ADD CONSTRAINT gen_cuenta_medio_pago_id_usuario_creacion_fkey
            FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuarios(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'gen_cuenta_medio_pago_id_usuario_modificacion_fkey') THEN
        ALTER TABLE gen_cuenta_medio_pago
            ADD CONSTRAINT gen_cuenta_medio_pago_id_usuario_modificacion_fkey
            FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuarios(id);
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_gen_cuenta_medio_pago
    ON gen_cuenta_medio_pago USING btree (id_cuenta_bancaria, id_medio_pago) WHERE estado = 1;

CREATE INDEX IF NOT EXISTS idx_gen_cuenta_medio_pago_medio
    ON gen_cuenta_medio_pago USING btree (id_medio_pago) WHERE estado = 1;

-- -----------------------------------------------------------------------------
-- 3. fin_medio_pago_config — fuente única del comportamiento de cada medio
-- -----------------------------------------------------------------------------
-- Reemplaza los `UPPER(mp.nombre) IN ('EFECTIVO','YAPE','PLIN')` repartidos por
-- fin_caja_calcular_totales y compañía. Mismo criterio que F1 con
-- inv_signo_tipo_movimiento: el comportamiento se configura, no se infiere del
-- nombre del catálogo.
--
--   es_efectivo               -> billetes y monedas en el cajón.
--   afecta_caja               -> entra al arqueo de la sesión de caja.
--   requiere_cuenta_bancaria  -> exige id_cuenta_bancaria de la empresa.
--   requiere_numero_operacion -> exige número de operación / voucher.

CREATE TABLE IF NOT EXISTS fin_medio_pago_config (
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
    fecha_modificacion timestamp without time zone DEFAULT now()
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fin_medio_pago_config_pkey') THEN
        ALTER TABLE fin_medio_pago_config
            ADD CONSTRAINT fin_medio_pago_config_pkey PRIMARY KEY (id_medio_pago);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fin_medio_pago_config_id_medio_fkey') THEN
        ALTER TABLE fin_medio_pago_config
            ADD CONSTRAINT fin_medio_pago_config_id_medio_fkey
            FOREIGN KEY (id_medio_pago) REFERENCES gen_lista_opciones(id);
    END IF;
    -- El efectivo nunca exige cuenta bancaria; el crédito no mueve dinero todavía.
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fin_medio_pago_config_coherente') THEN
        ALTER TABLE fin_medio_pago_config
            ADD CONSTRAINT fin_medio_pago_config_coherente
            CHECK (NOT ((es_efectivo OR es_credito) AND requiere_cuenta_bancaria));
    END IF;
END $$;

-- Semilla: refleja exactamente lo que hoy hace fin_caja_calcular_totales
-- (EFECTIVO / YAPE / PLIN afectan caja) y añade la exigencia de cuenta.
INSERT INTO fin_medio_pago_config (
    id_medio_pago, es_efectivo, afecta_caja, requiere_cuenta_bancaria,
    requiere_numero_operacion, es_credito, orden
)
SELECT o.id, v.es_efectivo, v.afecta_caja, v.requiere_cuenta, v.requiere_op, v.es_credito, v.orden
FROM (
    VALUES
        ('EFECTIVO',      TRUE,  TRUE,  FALSE, FALSE, FALSE, 10),
        ('YAPE',          FALSE, TRUE,  TRUE,  TRUE,  FALSE, 20),
        ('PLIN',          FALSE, TRUE,  TRUE,  TRUE,  FALSE, 30),
        ('TRANSFERENCIA', FALSE, FALSE, TRUE,  TRUE,  FALSE, 40),
        ('DEPOSITO',      FALSE, FALSE, TRUE,  TRUE,  FALSE, 50),
        ('TARJETA',       FALSE, FALSE, TRUE,  FALSE, FALSE, 60),
        ('CHEQUE',        FALSE, FALSE, TRUE,  TRUE,  FALSE, 70),
        ('CREDITO',       FALSE, FALSE, FALSE, FALSE, TRUE,  80)
) AS v(nombre, es_efectivo, afecta_caja, requiere_cuenta, requiere_op, es_credito, orden)
JOIN gen_lista l ON l.nombre = 'MedioPago'
JOIN gen_lista_opciones o ON o.id_lista = l.id AND UPPER(o.nombre) = v.nombre
WHERE NOT EXISTS (
    SELECT 1 FROM fin_medio_pago_config c WHERE c.id_medio_pago = o.id
);

-- -----------------------------------------------------------------------------
-- 4. ven_comprobante_pago — cobro multi-medio de una venta
-- -----------------------------------------------------------------------------
-- ven_comprobante.id_medio_pago se conserva como derivado de conveniencia:
-- guarda el medio de la línea de mayor monto (ver ven_sincronizar_pagos_comprobante).

CREATE TABLE IF NOT EXISTS ven_comprobante_pago (
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
    fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE SEQUENCE IF NOT EXISTS ven_comprobante_pago_id_seq
    AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE ven_comprobante_pago_id_seq OWNED BY public.ven_comprobante_pago.id;

ALTER TABLE ven_comprobante_pago
    ALTER COLUMN id SET DEFAULT nextval('public.ven_comprobante_pago_id_seq'::regclass);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_pkey') THEN
        ALTER TABLE ven_comprobante_pago ADD CONSTRAINT ven_comprobante_pago_pkey PRIMARY KEY (id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_monto_check') THEN
        ALTER TABLE ven_comprobante_pago
            ADD CONSTRAINT ven_comprobante_pago_monto_check CHECK (monto > (0)::numeric);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_id_comprobante_fkey') THEN
        ALTER TABLE ven_comprobante_pago
            ADD CONSTRAINT ven_comprobante_pago_id_comprobante_fkey
            FOREIGN KEY (id_comprobante) REFERENCES ven_comprobante(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_id_medio_pago_fkey') THEN
        ALTER TABLE ven_comprobante_pago
            ADD CONSTRAINT ven_comprobante_pago_id_medio_pago_fkey
            FOREIGN KEY (id_medio_pago) REFERENCES gen_lista_opciones(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_id_cuenta_bancaria_fkey') THEN
        ALTER TABLE ven_comprobante_pago
            ADD CONSTRAINT ven_comprobante_pago_id_cuenta_bancaria_fkey
            FOREIGN KEY (id_cuenta_bancaria) REFERENCES gen_cuenta_bancaria(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_id_usuario_creacion_fkey') THEN
        ALTER TABLE ven_comprobante_pago
            ADD CONSTRAINT ven_comprobante_pago_id_usuario_creacion_fkey
            FOREIGN KEY (id_usuario_creacion) REFERENCES auth_usuarios(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ven_comprobante_pago_id_usuario_modificacion_fkey') THEN
        ALTER TABLE ven_comprobante_pago
            ADD CONSTRAINT ven_comprobante_pago_id_usuario_modificacion_fkey
            FOREIGN KEY (id_usuario_modificacion) REFERENCES auth_usuarios(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ven_comprobante_pago_comprobante
    ON ven_comprobante_pago USING btree (id_comprobante) WHERE estado = 1;

CREATE INDEX IF NOT EXISTS idx_ven_comprobante_pago_cuenta
    ON ven_comprobante_pago USING btree (id_cuenta_bancaria) WHERE estado = 1;

-- -----------------------------------------------------------------------------
-- 5. id_cuenta_bancaria donde falta (plan §F3, apunte 1.a.i)
-- -----------------------------------------------------------------------------
-- fin_pago y fin_caja_deposito ya la tenían.

ALTER TABLE fin_caja_gasto
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria integer;

ALTER TABLE fin_garantia
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria integer;

ALTER TABLE fin_garantia
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria_reembolso integer;

ALTER TABLE ven_garantia
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria integer;

ALTER TABLE ven_garantia
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria_reembolso integer;

ALTER TABLE ven_garantia_movimiento
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria integer;

ALTER TABLE ven_garantia_movimiento
    ADD COLUMN IF NOT EXISTS numero_operacion character varying(80);

DO $$
DECLARE
    v RECORD;
BEGIN
    FOR v IN
        SELECT * FROM (
            VALUES
                ('fin_caja_gasto',          'id_cuenta_bancaria'),
                ('fin_garantia',            'id_cuenta_bancaria'),
                ('fin_garantia',            'id_cuenta_bancaria_reembolso'),
                ('ven_garantia',            'id_cuenta_bancaria'),
                ('ven_garantia',            'id_cuenta_bancaria_reembolso'),
                ('ven_garantia_movimiento', 'id_cuenta_bancaria')
        ) AS t(tabla, columna)
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = v.tabla || '_' || v.columna || '_fkey'
        ) THEN
            EXECUTE format(
                'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES gen_cuenta_bancaria(id)',
                v.tabla, v.tabla || '_' || v.columna || '_fkey', v.columna
            );
        END IF;
    END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_fin_caja_gasto_cuenta
    ON fin_caja_gasto USING btree (id_cuenta_bancaria) WHERE estado = 1;

CREATE INDEX IF NOT EXISTS idx_ven_garantia_mov_cuenta
    ON ven_garantia_movimiento USING btree (id_cuenta_bancaria) WHERE estado = 1;

-- -----------------------------------------------------------------------------
-- 6. Permisos
-- -----------------------------------------------------------------------------
-- No se añaden banderas nuevas. Las cuentas de la empresa se gestionan por los
-- mismos endpoints (y con los mismos permisos cuentas_bancarias.*) que las de
-- cliente, y el historial por resúmenes es el mismo libro diario, ya cubierto
-- por caja.libro_diario. Una bandera que no gobierna nada solo confunde el
-- mantenimiento de roles.
