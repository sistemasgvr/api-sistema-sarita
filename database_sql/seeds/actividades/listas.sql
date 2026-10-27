-- Listas y opciones del módulo actividades
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
        48,
        'TipoActividad',
        'Actividades que se pueden realizar en dia de trabajo',
        1
      ),
      (49, 'EstadoActividad', 'Segun la actividad', 1),
      (
        50,
        'PrioridadActividad',
        'La actividad presenta mas relevancia que otras',
        1
      ),
      (
        73,
        'EstadoVerificacionItem',
        'Resultado de verificar un ítem de actividad',
        1
      ),
      (
        74,
        'TipoOrigenActividad',
        'De dónde nace la actividad: venta, orden de salida o préstamo',
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
      (164, 'TipoActividad', 'ATENCIÓN', NULL, 1),
      (165, 'TipoActividad', 'RECOJO', NULL, 1),
      (166, 'TipoActividad', 'COBRANZAS', NULL, 1),
      (167, 'TipoActividad', 'MANTENIMIENTO', NULL, 1),
      (168, 'TipoActividad', 'CHARLAS', NULL, 1),
      (169, 'TipoActividad', 'OTROS', NULL, 1),
      (170, 'EstadoActividad', 'PENDIENTE', NULL, 1),
      (171, 'EstadoActividad', 'REALIZADA', NULL, 1),
      (172, 'PrioridadActividad', 'ALTA', NULL, 1),
      (173, 'PrioridadActividad', 'MEDIA', NULL, 1),
      (174, 'PrioridadActividad', 'BAJA', NULL, 1),
      (289, 'TipoActividad', 'REPARTO', 'Reparto', 1),
      (
        290,
        'EstadoActividad',
        'CANCELADA',
        'Cancelada',
        1
      ),
      (
        361,
        'EstadoVerificacionItem',
        'OK',
        'Verificado sin novedad',
        1
      ),
      (
        362,
        'EstadoVerificacionItem',
        'CON_OBSERVACION',
        'Verificado con observación',
        1
      ),
      (
        363,
        'EstadoVerificacionItem',
        'PENDIENTE',
        'Sin verificar',
        1
      ),
      (
        364,
        'TipoOrigenActividad',
        'PRESTAMO',
        'Nace de un préstamo de cilindros',
        1
      ),
      (
        365,
        'TipoOrigenActividad',
        'VENTA',
        'Nace de un comprobante de venta',
        1
      ),
      (
        366,
        'TipoOrigenActividad',
        'ORDEN_SALIDA',
        'Nace de un documento de salida',
        1
      ),
      (
        370,
        'TipoOrigenActividad',
        'ALQUILER',
        'Nace de un alquiler de cilindros',
        1
      ),
      (
        371,
        'EstadoActividad',
        'EN_RUTA',
        'La entrega salio del almacen y va camino al cliente',
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
