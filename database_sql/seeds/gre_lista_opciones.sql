-- Catálogos Guías de Remisión (GRE) — ejecutar en BD existentes
-- Idempotente (NOT EXISTS)

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TipoGuiaRemision', '09=GRE Remitente, 31=GRE Transportista'),
        ('ModalidadTraslado', '01=Transporte público, 02=Transporte privado'),
        ('MotivoTraslado', 'Catálogo 20 SUNAT — motivo de traslado'),
        ('EstadoGuiaRemision', 'Estado operativo interno de la guía')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

-- TipoGuiaRemision (código SUNAT en descripcion)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('GRE_REMITENTE', '09'),
        ('GRE_TRANSPORTISTA', '31')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoGuiaRemision'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- ModalidadTraslado
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PUBLICO', '01'),
        ('PRIVADO', '02')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'ModalidadTraslado'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- MotivoTraslado (códigos SUNAT catálogo 20 — los más usados primero)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('VENTA', '01'),
        ('COMPRA', '02'),
        ('TRASLADO_ENTRE_ESTABLECIMIENTOS', '04'),
        ('CONSIGNACION', '05'),
        ('DEVOLUCION', '06'),
        ('RECOJO_BIENES_TRANSFORMADOS', '07'),
        ('IMPORTACION', '08'),
        ('EXPORTACION', '09'),
        ('OTROS', '13'),
        ('VENTA_SUJETA_CONFIRMACION', '14'),
        ('TRASLADO_EMISOR_ITINERANTE', '18'),
        ('TRASLADO_ZONA_PRIMARIA', '19')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoTraslado'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- EstadoGuiaRemision (operativo interno)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Registrada, pendiente de envío'),
        ('ENVIADO', 'Enviada / en tránsito'),
        ('RECIBIDO', 'Recepcionada en destino'),
        ('ANULADO', 'Anulada')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoGuiaRemision'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- Unidad KGM para peso bruto SUNAT (si no existe)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('KGM', 'Kilogramo (SUNAT)')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'UnidadMedida'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
