-- Listas y opciones del módulo compras
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
        54,
        'TipoRegistroCompra',
        'Se registra el tipo de compra para designar gastos.',
        1
      ),
      (55, 'CategoriaGasto', NULL, 1),
      (
        77,
        'RegimenRetencion',
        'Catálogo 23 SUNAT — régimen de retención (código en descripcion)',
        1
      ),
      (
        83,
        'TasaRetencion',
        'Tasas de retención por régimen (código del régimen en descripcion)',
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
        182,
        'TipoRegistroCompra',
        'COMPRA_A_PROVEEDOR',
        NULL,
        1
      ),
      (
        186,
        'TipoRegistroCompra',
        'GASTO_OPERATIVO',
        NULL,
        1
      ),
      (187, 'CategoriaGasto', 'COMBUSTIBLE', NULL, 1),
      (188, 'CategoriaGasto', 'FLETE', NULL, 1),
      (189, 'CategoriaGasto', 'MANTENIMIENTO', NULL, 1),
      (190, 'CategoriaGasto', 'OTROS', NULL, 1),
      (
        194,
        'CategoriaGasto',
        'IMPUESTOS',
        'IGV, Renta, Planilla (detalle en observación del gasto)',
        1
      ),
      (195, 'CategoriaGasto', 'UTILES_OFICINA', NULL, 1),
      (
        306,
        'CategoriaGasto',
        'UTILES_LIMPIEZA',
        'Útiles de limpieza',
        1
      ),
      (
        307,
        'CategoriaGasto',
        'SUELDOS',
        'Sueldos y planilla de personal',
        1
      ),
      (
        308,
        'CategoriaGasto',
        'BIDONES_AGUA',
        'Bidones de agua',
        1
      ),
      (309, 'CategoriaGasto', 'VIATICOS', 'Viáticos', 1),
      (
        310,
        'CategoriaGasto',
        'ALQUILER_LOCAL',
        'Alquiler de local',
        1
      ),
      (
        311,
        'CategoriaGasto',
        'SERVICIOS_BASICOS',
        'Luz, agua, teléfono, internet',
        1
      ),
      (
        375,
        'CategoriaGasto',
        'Recarga de Balon',
        'Recarga de balones a planta externa',
        1
      ),
      (
        387,
        'RegimenRetencion',
        'Régimen con tasa especial',
        '02',
        1
      ),
      (
        388,
        'RegimenRetencion',
        'Régimen general',
        '01',
        1
      ),
      (392, 'TasaRetencion', '6%', '02', 1),
      (393, 'TasaRetencion', '3%', '01', 1),
      (
        398,
        'CategoriaGasto',
        'COMPRA DE BALONES DE PROPANO',
        NULL,
        1
      ),
      (
        399,
        'CategoriaGasto',
        'COMPRA DE ACCESORIOS',
        NULL,
        1
      ),
      (400, 'CategoriaGasto', 'COCHERA', NULL, 1),
      (
        401,
        'CategoriaGasto',
        'REEMBOLSO DE CILINDROS',
        NULL,
        1
      ),
      (404, 'CategoriaGasto', 'CARBURO', NULL, 1),
      (
        407,
        'CategoriaGasto',
        'CANJE DE CILINDROS',
        NULL,
        1
      ),
      (412, 'CategoriaGasto', 'AFP INTEGRA', NULL, 1),
      (413, 'CategoriaGasto', 'AFP PRIMA', NULL, 1),
      (415, 'CategoriaGasto', 'FLETE LOCAL', NULL, 1),
      (419, 'CategoriaGasto', 'PEAJE', NULL, 1),
      (421, 'CategoriaGasto', 'LICENCIAS', NULL, 1),
      (
        422,
        'CategoriaGasto',
        'COMPRA DE CILINDROS + KIT COMPLETO',
        NULL,
        1
      ),
      (
        423,
        'CategoriaGasto',
        'CANJE DE CILINDROS MEDICINALES',
        NULL,
        1
      ),
      (
        424,
        'CategoriaGasto',
        'REEMBOLSO POR GARANTIA DE CILINDRO',
        NULL,
        1
      ),
      (
        425,
        'CategoriaGasto',
        'REEMBOLSO POR COMPRA DE BALON DE UN PROVEEDOR',
        NULL,
        1
      ),
      (
        426,
        'CategoriaGasto',
        'REEMBOSLO GENERADO POR UN PROVEEDOR',
        NULL,
        1
      ),
      (427, 'CategoriaGasto', 'PAGO DE ONP', NULL, 1),
      (428, 'CategoriaGasto', 'PAGO DE ESSALUD', NULL, 1),
      (429, 'CategoriaGasto', 'ASESORIA', NULL, 1),
      (
        430,
        'CategoriaGasto',
        'SERVICIOS DE MARKETING',
        NULL,
        1
      ),
      (
        432,
        'CategoriaGasto',
        'RECARGA DE CILINDROS MEDICINALES',
        NULL,
        1
      ),
      (
        433,
        'CategoriaGasto',
        'COMPRA DE CILINDROS',
        NULL,
        1
      ),
      (
        434,
        'CategoriaGasto',
        'REPARACIÓN REGULADOR',
        NULL,
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
