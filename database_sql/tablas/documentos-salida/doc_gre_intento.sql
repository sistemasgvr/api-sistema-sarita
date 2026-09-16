-- Table: doc_gre_intento
-- Creada por 20260916_gre_fecha_e_intentos.sql; ampliada por
-- 20260916_gre_p0_fiscal_numeracion_entorno.sql (empresa, entorno, consultas).
--
-- Cada envío de GRE al PSE queda registrado ANTES de contactar al proveedor,
-- con la empresa, el RUC y el entorno (beta/produccion) con los que salió.
-- El índice parcial garantiza un solo intento abierto por documento: dos
-- solicitudes concurrentes producen un único envío.

CREATE TABLE doc_gre_intento (
    id bigserial PRIMARY KEY,
    id_doc_salida integer NOT NULL REFERENCES doc_salida(id),
    estado text NOT NULL CHECK (estado IN ('ENVIANDO','POR_CONFIRMAR','PENDIENTE','ACEPTADO','RECHAZADO')),
    solicitud jsonb NOT NULL,
    documento jsonb NOT NULL,
    respuesta jsonb,
    id_usuario integer,
    id_empresa integer REFERENCES gen_empresa(id),
    ruc_emisor varchar(11),
    entorno text,
    id_empresa_pse integer,
    consultas integer NOT NULL DEFAULT 0,
    proxima_consulta timestamptz,
    creado timestamptz NOT NULL DEFAULT now(),
    actualizado timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_doc_gre_intento_abierto ON doc_gre_intento(id_doc_salida)
WHERE estado <> 'RECHAZADO';

CREATE INDEX ix_doc_gre_intento_pendientes ON doc_gre_intento(proxima_consulta)
WHERE estado IN ('PENDIENTE', 'POR_CONFIRMAR');
