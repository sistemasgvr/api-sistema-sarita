-- Destinatario sin cliente registrado (nombre + documento para SUNAT)
ALTER TABLE gre_guia_remision
  ADD COLUMN IF NOT EXISTS destinatario_nombre VARCHAR(255),
  ADD COLUMN IF NOT EXISTS destinatario_documento VARCHAR(20);
