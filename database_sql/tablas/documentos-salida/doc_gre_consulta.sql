-- Table: doc_gre_consulta
-- Creada por 20260916_gre_fecha_e_intentos.sql.
-- Cada consulta de ticket al PSE (manual o automática) conserva su respuesta
-- completa contra el intento: el historial no se sobreescribe.

CREATE TABLE doc_gre_consulta (
    id bigserial PRIMARY KEY,
    id_intento bigint NOT NULL REFERENCES doc_gre_intento(id),
    respuesta jsonb NOT NULL,
    creado timestamptz NOT NULL DEFAULT now()
);
