-- Catálogos Documento de salida (Fase 2).
-- Idempotente por nombre. Sin IDs fijos de lista (no están en ListaIds del FE).

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TipoOrdenSalida', 'Tipos de documento de salida unificado'),
        ('EstadoCicloSalida', 'Ciclo de vida del documento de salida')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ORDEN_SALIDA_VENTA', 'Orden de salida originada en una venta'),
        ('ORDEN_SALIDA_INTERNA', 'Orden de salida interna (sin venta)'),
        ('RECARGA_PLANTA_EXTERNA', 'Envío a planta externa para recarga'),
        ('RETORNO_PLANTA_EXTERNA', 'Retorno desde planta externa'),
        ('TRASLADO', 'Traslado entre almacenes')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoOrdenSalida'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('BORRADOR', 'Documento editable, sin movimiento de inventario'),
        ('GENERADA', 'Orden generada (stock aplicado si corresponde)'),
        ('EMITIDA_SUNAT', 'GRE aceptada por SUNAT'),
        ('ANULADA', 'Documento anulado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoCicloSalida'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoDocumentoRef.ORDEN_SALIDA (requerido por doc_generar_salida / inv_revertir)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, 'ORDEN_SALIDA', 'Documento de salida unificado (orden / GRE / planta)'
FROM gen_lista l
WHERE l.nombre = 'TipoDocumentoRef'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = 'ORDEN_SALIDA'
  );
