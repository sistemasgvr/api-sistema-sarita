-- Condiciones de pago estándar
INSERT INTO
  gen_condicion_pago (
    codigo,
    nombre,
    dias_credito,
    numero_cuotas,
    dia_mes_pago,
    estado
  )
VALUES
  ('CRED7', 'Crédito 7 días', 7, NULL, NULL, 1),
  ('CRED15', 'Crédito 15 días', 15, NULL, NULL, 1),
  ('CRED30', 'Crédito 30 días', 30, NULL, NULL, 1),
  ('CRED45', 'Crédito 45 días', 45, NULL, NULL, 1),
  ('CRED60', 'Crédito 60 días', 60, NULL, NULL, 1),
  (
    'CUOT2',
    '2 cuotas mensuales (día 15)',
    0,
    2,
    15,
    1
  ),
  (
    'CUOT3',
    '3 cuotas mensuales (día 15)',
    0,
    3,
    15,
    1
  ),
  (
    'CUOT4',
    '4 cuotas mensuales (día 15)',
    0,
    4,
    15,
    1
  ),
  (
    'CUOT6',
    '6 cuotas mensuales (día 15)',
    0,
    6,
    15,
    1
  ),
  (
    'CUOT3F',
    '3 cuotas mensuales (fin de mes)',
    0,
    3,
    28,
    1
  ),
  ('CONTADO', 'Contado', 0, NULL, NULL, 1),
  ('CREDITO', 'Crédito 10 días', 10, NULL, NULL, 1)
ON CONFLICT (codigo) DO NOTHING;
