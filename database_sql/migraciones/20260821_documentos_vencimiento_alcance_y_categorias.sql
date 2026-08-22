-- ============================================================
-- Módulo Documentos de Vencimiento — migración de soporte
-- ============================================================

-- 1) Distinguir documentos de LOCAL (sucursal) vs EMPRESA (ambos NULL = empresa/general).
--    id_vehiculo NOT NULL = documento atado a un vehículo (ya existía).
--    id_sucursal NOT NULL = documento atado a un local/sucursal.
--    Ambos NULL = documento de alcance empresa (ej. BPA, salubridad si aplica a toda la empresa).
ALTER TABLE gen_documento_vencimiento
    ADD COLUMN IF NOT EXISTS id_sucursal INT REFERENCES gen_sucursal(id);

-- 2) Catálogo de categorías: agregar los 5 tipos específicos de la nota (id_lista = 42,
--    'CategoriaVencimiento'). Ya existían SOAT/INSPECCION/MUNICIPAL/SEGURIDAD/CERTIFICADO/OTRO
--    (genéricos, usados sobre todo para vehículos); estos son específicos y nombrados,
--    tal como pide la nota ("sobre todo defensa civil y saneamiento ambiental").
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, id_usuario_creacion)
SELECT 42, v.nombre, v.descripcion, 1
FROM (VALUES
    ('BPA', 'Buenas Prácticas de Almacenamiento'),
    ('SALUBRIDAD', 'Certificado de Salubridad'),
    ('DEFENSA_CIVIL', 'Certificado / control de Defensa Civil'),
    ('SANEAMIENTO_AMBIENTAL', 'Certificado de Saneamiento Ambiental'),
    ('EXTINTORES', 'Control de vencimiento de extintores')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista_opciones WHERE id_lista = 42 AND nombre = v.nombre
);
