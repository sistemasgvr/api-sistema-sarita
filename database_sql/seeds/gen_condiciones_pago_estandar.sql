-- Condiciones de pago estándar (contado / crédito / cuotas mensuales).
-- Idempotente: actualiza CONTADO y CREDITO; inserta el resto si no existen.

SET TIME ZONE 'America/Lima';

UPDATE gen_condicion_pago
SET nombre = 'Contado',
    dias_credito = 0,
    numero_cuotas = NULL,
    dia_mes_pago = NULL,
    fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CONTADO' AND estado = 1;

UPDATE gen_condicion_pago
SET nombre = 'Crédito 10 días',
    dias_credito = 10,
    numero_cuotas = NULL,
    dia_mes_pago = NULL,
    fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CREDITO' AND estado = 1;

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CRED7', 'Crédito 7 días', 7, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED7' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CRED15', 'Crédito 15 días', 15, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED15' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CRED30', 'Crédito 30 días', 30, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED30' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CRED45', 'Crédito 45 días', 45, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED45' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CRED60', 'Crédito 60 días', 60, NULL, NULL
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED60' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CUOT2', '2 cuotas mensuales (día 15)', 0, 2, 15
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT2' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CUOT3', '3 cuotas mensuales (día 15)', 0, 3, 15
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT3' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CUOT4', '4 cuotas mensuales (día 15)', 0, 4, 15
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT4' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CUOT6', '6 cuotas mensuales (día 15)', 0, 6, 15
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT6' AND estado = 1);

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago)
SELECT 'CUOT3F', '3 cuotas mensuales (fin de mes)', 0, 3, 28
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT3F' AND estado = 1);
