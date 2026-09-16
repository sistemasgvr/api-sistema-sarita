BEGIN;
-- Los archivos no deben sobrescribir el CDR ni cambiar el estado fiscal.
-- Se vinculan al intento exacto, de modo que un reintento no reutilice otro PDF.
CREATE TABLE IF NOT EXISTS doc_gre_archivo (
 id_intento bigint PRIMARY KEY REFERENCES doc_gre_intento(id),
 pdf_base64 text NOT NULL,
 creado timestamptz NOT NULL DEFAULT now()
);
COMMIT;
