-- Listas y opciones del módulo documentos-salida
INSERT INTO
  gen_lista (id, nombre, descripcion, estado)
SELECT
  v.id,
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      (
        36,
        'EstadoGuiaRemision',
        'Estado interno de la guía de remisión',
        1
      ),
      (
        43,
        'TipoGuiaRemision',
        '09=GRE Remitente, 31=GRE Transportista',
        1
      ),
      (
        44,
        'ModalidadTraslado',
        '01=Transporte público, 02=Transporte privado',
        1
      ),
      (
        45,
        'MotivoTraslado',
        'Catálogo 20 SUNAT — motivo de traslado',
        1
      ),
      (
        70,
        'TipoOrdenSalida',
        'Tipos de documento de salida unificado',
        1
      ),
      (
        71,
        'EstadoCicloSalida',
        'Ciclo de vida del documento de salida',
        1
      )
  ) AS v (id, nombre, descripcion, estado)
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      gen_lista l
    WHERE
      l.nombre = v.nombre
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO
  gen_lista_opciones (id, id_lista, nombre, descripcion, estado)
SELECT
  v.id,
  l.id,
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      (
        121,
        'EstadoGuiaRemision',
        'RECIBIDO',
        'Mercadería recibida',
        1
      ),
      (
        122,
        'EstadoGuiaRemision',
        'ANULADO',
        'Guía anulada',
        1
      ),
      (
        123,
        'EstadoGuiaRemision',
        'PENDIENTE',
        'Guía pendiente de envío',
        1
      ),
      (144, 'TipoGuiaRemision', 'GRE_REMITENTE', '09', 1),
      (
        145,
        'TipoGuiaRemision',
        'GRE_TRANSPORTISTA',
        '31',
        1
      ),
      (146, 'ModalidadTraslado', 'PUBLICO', '01', 1),
      (147, 'ModalidadTraslado', 'PRIVADO', '02', 1),
      (148, 'MotivoTraslado', 'DEVOLUCION', '06', 1),
      (149, 'MotivoTraslado', 'COMPRA', '02', 1),
      (
        150,
        'MotivoTraslado',
        'TRASLADO_EMISOR_ITINERANTE',
        '18',
        1
      ),
      (151, 'MotivoTraslado', 'CONSIGNACION', '05', 1),
      (
        152,
        'MotivoTraslado',
        'RECOJO_BIENES_TRANSFORMADOS',
        '07',
        1
      ),
      (153, 'MotivoTraslado', 'IMPORTACION', '08', 1),
      (154, 'MotivoTraslado', 'OTROS', '13', 1),
      (155, 'MotivoTraslado', 'VENTA', '01', 1),
      (
        156,
        'MotivoTraslado',
        'TRASLADO_ZONA_PRIMARIA',
        '19',
        1
      ),
      (
        157,
        'MotivoTraslado',
        'VENTA_SUJETA_CONFIRMACION',
        '14',
        1
      ),
      (
        158,
        'MotivoTraslado',
        'TRASLADO_ENTRE_ESTABLECIMIENTOS',
        '04',
        1
      ),
      (159, 'MotivoTraslado', 'EXPORTACION', '09', 1),
      (
        239,
        'EstadoGuiaRemision',
        'ENVIADO',
        'Enviado',
        1
      ),
      (
        325,
        'TipoOrdenSalida',
        'TRASLADO',
        'Traslado entre almacenes',
        1
      ),
      (
        326,
        'TipoOrdenSalida',
        'ORDEN_SALIDA_INTERNA',
        'Orden de salida interna (sin venta)',
        1
      ),
      (
        327,
        'TipoOrdenSalida',
        'RECARGA_PLANTA_EXTERNA',
        'Envío a planta externa para recarga',
        1
      ),
      (
        328,
        'TipoOrdenSalida',
        'ORDEN_SALIDA_VENTA',
        'Orden de salida originada en una venta',
        1
      ),
      (
        329,
        'EstadoCicloSalida',
        'ANULADA',
        'Documento anulado',
        1
      ),
      (
        330,
        'EstadoCicloSalida',
        'BORRADOR',
        'Documento editable, sin movimiento de inventario',
        1
      ),
      (
        331,
        'EstadoCicloSalida',
        'EMITIDA_SUNAT',
        'GRE aceptada por SUNAT',
        1
      ),
      (
        332,
        'EstadoCicloSalida',
        'GENERADA',
        'Orden generada (stock aplicado si corresponde)',
        1
      )
  ) AS v (id, lista, nombre, descripcion, estado)
  JOIN gen_lista l ON l.nombre = v.lista
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      gen_lista_opciones o
    WHERE
      o.id_lista = l.id
      AND o.nombre = v.nombre
  )
ON CONFLICT (id) DO NOTHING;

SELECT
  setval(
    pg_get_serial_sequence('gen_lista', 'id'),
    (
      SELECT
        COALESCE(MAX(id), 0) + 1
      FROM
        gen_lista
    ),
    FALSE
  );

SELECT
  setval(
    pg_get_serial_sequence('gen_lista_opciones', 'id'),
    (
      SELECT
        COALESCE(MAX(id), 0) + 1
      FROM
        gen_lista_opciones
    ),
    FALSE
  );
