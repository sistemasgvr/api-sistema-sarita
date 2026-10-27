-- Listas y opciones del módulo finanzas
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
        40,
        'Bancos',
        'Para lista de bancos (BCP,BBVA,INTERBANK)',
        1
      ),
      (41, 'TipoCuenta', 'TIpos  de Cuenta Bancaria', 1),
      (
        57,
        'TipoCuentaFinanciera',
        'COBRAR (cliente) o PAGAR (proveedor)',
        1
      ),
      (58, 'MedioPago', 'Medios de pago disponibles', 1),
      (
        65,
        'EstadoCaja',
        'Estado de sesión de caja diaria',
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
      (132, 'Bancos', 'SCOTIABANK', 'Scotiabank', 1),
      (133, 'Bancos', 'BANBIF', 'BanBif', 1),
      (134, 'Bancos', 'BBVA', 'BBVA Continental', 1),
      (
        135,
        'Bancos',
        'BCP',
        'Banco de Crédito del Perú',
        1
      ),
      (136, 'Bancos', 'INTERBANK', 'Interbank', 1),
      (
        137,
        'TipoCuenta',
        'CCI',
        'Cuenta interbancaria',
        1
      ),
      (
        138,
        'TipoCuenta',
        'YAPE',
        'Billetera digital Yape',
        1
      ),
      (
        139,
        'TipoCuenta',
        'CORRIENTE',
        'Cuenta corriente',
        1
      ),
      (
        140,
        'TipoCuenta',
        'PLIN',
        'Billetera digital Plin',
        1
      ),
      (
        141,
        'TipoCuenta',
        'AHORROS',
        'Cuenta de ahorros',
        1
      ),
      (197, 'MedioPago', 'PLIN', 'Pago con Plin', 1),
      (
        198,
        'MedioPago',
        'EFECTIVO',
        'Pago en efectivo',
        1
      ),
      (
        199,
        'MedioPago',
        'TRANSFERENCIA',
        'Transferencia bancaria',
        1
      ),
      (200, 'MedioPago', 'YAPE', 'Pago con Yape', 1),
      (
        201,
        'MedioPago',
        'DEPOSITO',
        'Depósito en cuenta',
        1
      ),
      (202, 'MedioPago', 'CHEQUE', 'Pago con cheque', 1),
      (
        266,
        'TipoCuentaFinanciera',
        'PAGAR',
        'Por pagar',
        1
      ),
      (
        267,
        'TipoCuentaFinanciera',
        'COBRAR',
        'Por cobrar',
        1
      ),
      (268, 'MedioPago', 'TARJETA', 'Tarjeta', 1),
      (269, 'MedioPago', 'CREDITO', 'Crédito', 1),
      (280, 'EstadoCaja', 'ABIERTA', 'Abierta', 1),
      (281, 'EstadoCaja', 'CERRADA', 'Cerrada', 1),
      (
        374,
        'MedioPago',
        'AJUSTE_NC',
        'Abono automático por nota de crédito (no afecta caja)',
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
