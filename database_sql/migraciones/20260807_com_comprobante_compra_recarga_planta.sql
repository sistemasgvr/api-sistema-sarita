ALTER TABLE com_comprobante_compra
    ADD COLUMN IF NOT EXISTS id_recarga_planta INT REFERENCES bal_recarga_planta(id);
