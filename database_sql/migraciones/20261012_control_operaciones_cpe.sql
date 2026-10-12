BEGIN;
CREATE TABLE IF NOT EXISTS ven_cpe_operacion_control (
  id_empresa integer PRIMARY KEY REFERENCES gen_empresa(id),
  token uuid NOT NULL,
  vencimiento timestamptz NOT NULL
);
COMMIT;
