-- Listas y opciones del módulo inventario
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
        72,
        'TipoMovInvUnificado',
        'Tipos de movimiento de inv_movimiento (producto y balon unificados)',
        1
      ),
      (
        78,
        'NaturalezaMovInv',
        'Naturaleza del movimiento de inventario (Producto / Balón)',
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
        334,
        'TipoMovInvUnificado',
        'SALIDA_ALQUILER',
        'Salida de balon por alquiler',
        1
      ),
      (
        335,
        'TipoMovInvUnificado',
        'AJUSTE',
        'Ajuste manual de stock',
        1
      ),
      (
        336,
        'TipoMovInvUnificado',
        'SALIDA_VENTA',
        'Salida de balon por venta',
        1
      ),
      (
        337,
        'TipoMovInvUnificado',
        'RETORNO_LIMA',
        'Retorno de balon desde Lima',
        1
      ),
      (
        338,
        'TipoMovInvUnificado',
        'SALIDA',
        'Salida de producto de almacen',
        1
      ),
      (
        339,
        'TipoMovInvUnificado',
        'ENTRADA_GARANTIA',
        'Entrada de balon por garantia',
        1
      ),
      (
        340,
        'TipoMovInvUnificado',
        'SALIDA_ENTREGA_CLIENTE',
        'Salida de balon por entrega a cliente',
        1
      ),
      (
        341,
        'TipoMovInvUnificado',
        'ENTRADA_PLANTA_EXTERNA',
        'Entrada de balon desde planta externa',
        1
      ),
      (
        342,
        'TipoMovInvUnificado',
        'INGRESO',
        'Ingreso de producto a almacen',
        1
      ),
      (
        343,
        'TipoMovInvUnificado',
        'SALIDA_MANTENIMIENTO',
        'Salida de balon a mantenimiento',
        1
      ),
      (
        344,
        'TipoMovInvUnificado',
        'REPOSICION',
        'Reposicion manual de stock (sin documento)',
        1
      ),
      (
        345,
        'TipoMovInvUnificado',
        'SALIDA_PRESTAMO',
        'Salida de balon por prestamo',
        1
      ),
      (
        346,
        'TipoMovInvUnificado',
        'SALIDA_PLANTA_EXTERNA',
        'Salida de balon a planta externa',
        1
      ),
      (
        347,
        'TipoMovInvUnificado',
        'TRASLADO_LIMA',
        'Traslado de balon en ruta a Lima',
        1
      ),
      (
        348,
        'TipoMovInvUnificado',
        'RECARGA_CLIENTE',
        'Recarga de balon en mostrador para cliente',
        1
      ),
      (
        349,
        'TipoMovInvUnificado',
        'CONSUMO_INTERNO',
        'Consumo interno de stock',
        1
      ),
      (
        350,
        'TipoMovInvUnificado',
        'TRASLADO',
        'Traslado de producto entre almacenes',
        1
      ),
      (
        351,
        'TipoMovInvUnificado',
        'ENTRADA_MANTENIMIENTO',
        'Entrada de balon desde mantenimiento',
        1
      ),
      (
        352,
        'TipoMovInvUnificado',
        'ENTRADA_DEVOLUCION',
        'Entrada de balon por devolucion',
        1
      ),
      (
        353,
        'TipoMovInvUnificado',
        'ENTRADA_LLENADO',
        'Entrada de balon lleno',
        1
      ),
      (
        360,
        'TipoMovInvUnificado',
        'ENTRADA_COMPRA',
        'Entrada de balon por compra',
        1
      ),
      (
        376,
        'NaturalezaMovInv',
        'Producto',
        'PRODUCTO',
        1
      ),
      (377, 'NaturalezaMovInv', 'Balón', 'BALON', 1)
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


-- Gas de rutas manuales: separar el movimiento del gas del movimiento del envase.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, estado)
SELECT l.id, v.nombre, v.descripcion, 1
FROM gen_lista l CROSS JOIN (VALUES
    ('SALIDA_RUTA_PUEBLO', 'Salida de gas a ruta pueblos'),
    ('ENTRADA_RETORNO_RUTA_PUEBLO', 'Retorno de gas desde ruta pueblos')
) AS v(nombre, descripcion)
WHERE l.nombre = 'TipoMovInvUnificado'
  AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones o WHERE o.id_lista = l.id AND o.nombre = v.nombre);
