BEGIN;
ALTER TABLE ven_comprobante ADD COLUMN IF NOT EXISTS cpe_verificacion jsonb;
-- Exclusión compatible con conexiones PostgreSQL a través de un pool transaccional.
CREATE TABLE IF NOT EXISTS ven_cpe_verificacion_control (
    id smallint PRIMARY KEY CHECK (id=1),
    token uuid NOT NULL,
    vencimiento timestamptz NOT NULL
);
COMMIT;
