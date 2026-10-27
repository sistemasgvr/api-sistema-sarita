-- Comportamiento de cada medio de pago en caja y cobros
INSERT INTO
  fin_medio_pago_config (
    id_medio_pago,
    es_efectivo,
    afecta_caja,
    requiere_cuenta_bancaria,
    requiere_numero_operacion,
    es_credito,
    orden,
    estado
  )
SELECT
  o.id,
  v.es_efectivo,
  v.afecta_caja,
  v.requiere_cuenta_bancaria,
  v.requiere_numero_operacion,
  v.es_credito,
  v.orden,
  v.estado
FROM
  (
    VALUES
      (
        'EFECTIVO',
        TRUE,
        TRUE,
        FALSE,
        FALSE,
        FALSE,
        10,
        1
      ),
      ('YAPE', FALSE, TRUE, TRUE, TRUE, FALSE, 20, 1),
      ('PLIN', FALSE, TRUE, TRUE, TRUE, FALSE, 30, 1),
      (
        'TRANSFERENCIA',
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        FALSE,
        40,
        1
      ),
      (
        'DEPOSITO',
        FALSE,
        FALSE,
        TRUE,
        TRUE,
        FALSE,
        50,
        1
      ),
      (
        'TARJETA',
        FALSE,
        FALSE,
        TRUE,
        FALSE,
        FALSE,
        60,
        1
      ),
      ('CHEQUE', FALSE, FALSE, TRUE, TRUE, FALSE, 70, 1),
      (
        'CREDITO',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        TRUE,
        80,
        1
      ),
      (
        'AJUSTE_NC',
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        FALSE,
        900,
        1
      )
  ) AS v (
    medio,
    es_efectivo,
    afecta_caja,
    requiere_cuenta_bancaria,
    requiere_numero_operacion,
    es_credito,
    orden,
    estado
  )
  JOIN gen_lista l ON l.nombre = 'MedioPago'
  JOIN gen_lista_opciones o ON o.id_lista = l.id
  AND o.nombre = v.medio
ON CONFLICT (id_medio_pago) DO UPDATE
SET
  es_efectivo = EXCLUDED.es_efectivo,
  afecta_caja = EXCLUDED.afecta_caja,
  requiere_cuenta_bancaria = EXCLUDED.requiere_cuenta_bancaria,
  requiere_numero_operacion = EXCLUDED.requiere_numero_operacion,
  es_credito = EXCLUDED.es_credito,
  orden = EXCLUDED.orden,
  estado = EXCLUDED.estado,
  fecha_modificacion = NOW();
