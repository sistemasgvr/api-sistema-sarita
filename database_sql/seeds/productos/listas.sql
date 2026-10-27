-- Listas y opciones del módulo productos
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
        4,
        'TipoMovInv',
        'Tipos de movimiento de inventario',
        1
      ),
      (
        5,
        'TipoCatalogoPrecio',
        'Tipos de ítem en catálogo de precios',
        1
      ),
      (
        6,
        'TipoDocumentoRef',
        'Tipos de documento origen en movimientos de inventario',
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
        14,
        'TipoMovInv',
        'TRASLADO',
        'Traslado entre almacenes',
        1
      ),
      (
        15,
        'TipoMovInv',
        'AJUSTE',
        'Ajuste de inventario',
        1
      ),
      (
        16,
        'TipoDocumentoRef',
        'PRESTAMO',
        'Préstamo de cilindro',
        1
      ),
      (
        17,
        'TipoDocumentoRef',
        'ALQUILER',
        'Alquiler de cilindro',
        1
      ),
      (
        18,
        'TipoDocumentoRef',
        'GRE',
        'Guía de remisión electrónica',
        1
      ),
      (
        19,
        'TipoDocumentoRef',
        'RECARGA',
        'Recarga de gas',
        1
      ),
      (
        20,
        'TipoDocumentoRef',
        'FACTURA',
        'Factura de venta o compra',
        1
      ),
      (
        21,
        'TipoDocumentoRef',
        'COMPRA',
        'Comprobante de compra',
        1
      ),
      (35, 'TipoMovInv', 'INGRESO', 'Ingreso', 1),
      (38, 'TipoMovInv', 'SALIDA', 'Salida', 1),
      (
        39,
        'TipoDocumentoRef',
        'DEVOLUCION',
        'Devolución',
        1
      ),
      (
        40,
        'TipoCatalogoPrecio',
        'ACCESORIO',
        'Accesorio',
        1
      ),
      (
        41,
        'TipoCatalogoPrecio',
        'GARANTIA',
        'Garantía',
        1
      ),
      (
        42,
        'TipoCatalogoPrecio',
        'VENTA_CILINDRO',
        'Venta cilindro',
        1
      ),
      (
        43,
        'TipoCatalogoPrecio',
        'RECARGADO',
        'Recargado',
        1
      ),
      (
        128,
        'TipoDocumentoRef',
        'NOTA_DEBITO',
        'Nota de débito',
        1
      ),
      (
        129,
        'TipoDocumentoRef',
        'BOLETA',
        'Boleta de venta',
        1
      ),
      (
        130,
        'TipoDocumentoRef',
        'NOTA_CREDITO',
        'Nota de crédito',
        1
      ),
      (
        179,
        'TipoDocumentoRef',
        'MANTENIMIENTO',
        'Mantenimiento de cilindro',
        1
      ),
      (
        248,
        'TipoDocumentoRef',
        'NOTA_VENTA',
        'Nota de venta',
        1
      ),
      (
        285,
        'TipoDocumentoRef',
        'RUTA_PUEBLO',
        'Ruta pueblo',
        1
      ),
      (
        333,
        'TipoDocumentoRef',
        'ORDEN_SALIDA',
        'Documento de salida unificado (orden / GRE / planta)',
        1
      ),
      (
        394,
        'TipoDocumentoRef',
        'ACTIVIDAD',
        'Actividad (reparto / recojo)',
        1
      ),
      (
        418,
        'TipoDocumentoRef',
        'CAMBIO_VSD',
        'Cambio físico de balón de venta sin documento',
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
