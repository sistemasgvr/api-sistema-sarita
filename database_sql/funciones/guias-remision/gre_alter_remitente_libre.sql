-- Remitente sin cliente registrado (GRE transportista 31: nombre + documento SUNAT)
ALTER TABLE gre_guia_remision
  ADD COLUMN IF NOT EXISTS remitente_nombre VARCHAR(255),
  ADD COLUMN IF NOT EXISTS remitente_documento VARCHAR(20);
