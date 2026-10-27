-- Listas y opciones del módulo personal
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
        67,
        'AREAS_TRABAJADOR',
        'Áreas laborales del padrón de personal',
        1
      ),
      (
        68,
        'CARGOS_TRABAJADOR',
        'Cargos laborales del padrón de personal',
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
      (312, 'CARGOS_TRABAJADOR', 'TECNICO', 'Técnico', 1),
      (
        313,
        'CARGOS_TRABAJADOR',
        'AUXILIAR',
        'Auxiliar',
        1
      ),
      (314, 'CARGOS_TRABAJADOR', 'GERENTE', 'Gerente', 1),
      (
        315,
        'CARGOS_TRABAJADOR',
        'VENDEDOR',
        'Vendedor',
        1
      ),
      (
        318,
        'AREAS_TRABAJADOR',
        'ADMINISTRACION',
        'Administración',
        1
      ),
      (
        319,
        'AREAS_TRABAJADOR',
        'CONTABILIDAD',
        'Contabilidad',
        1
      ),
      (
        320,
        'AREAS_TRABAJADOR',
        'LOGISTICA',
        'Logística',
        1
      ),
      (
        321,
        'AREAS_TRABAJADOR',
        'OPERACIONES',
        'Operaciones',
        1
      ),
      (322, 'AREAS_TRABAJADOR', 'VENTAS', 'Ventas', 1),
      (
        323,
        'CARGOS_TRABAJADOR',
        'CONDUCTOR',
        'Conductor',
        1
      ),
      (
        324,
        'CARGOS_TRABAJADOR',
        'SUPERVISOR',
        'Supervisor',
        1
      ),
      (
        395,
        'CARGOS_TRABAJADOR',
        'Administradora',
        NULL,
        1
      ),
      (416, 'CARGOS_TRABAJADOR', 'Distribuidor', NULL, 1),
      (417, 'CARGOS_TRABAJADOR', 'Contador', NULL, 1)
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
