-- Condiciones de pago estándar (contado / crédito / cuotas mensuales).
-- Idempotente: inserta o actualiza por codigo.

SET TIME ZONE 'America/Lima';

-- Contado (obligatorio en POS)
INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CONTADO', 'Contado', 0, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CONTADO');

UPDATE gen_condicion_pago
SET nombre = 'Contado',
    dias_credito = 0,
    numero_cuotas = NULL,
    dia_mes_pago = NULL,
    estado = 1,
    fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CONTADO';

-- Crédito genérico 10 días (legado / código CREDITO)
INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CREDITO', 'Crédito 10 días', 10, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CREDITO');

UPDATE gen_condicion_pago
SET nombre = 'Crédito 10 días',
    dias_credito = 10,
    numero_cuotas = NULL,
    dia_mes_pago = NULL,
    estado = 1,
    fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CREDITO';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CRED7', 'Crédito 7 días', 7, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED7');

UPDATE gen_condicion_pago
SET nombre = 'Crédito 7 días', dias_credito = 7, numero_cuotas = NULL, dia_mes_pago = NULL, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CRED7';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CRED15', 'Crédito 15 días', 15, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED15');

UPDATE gen_condicion_pago
SET nombre = 'Crédito 15 días', dias_credito = 15, numero_cuotas = NULL, dia_mes_pago = NULL, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CRED15';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CRED30', 'Crédito 30 días', 30, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED30');

UPDATE gen_condicion_pago
SET nombre = 'Crédito 30 días', dias_credito = 30, numero_cuotas = NULL, dia_mes_pago = NULL, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CRED30';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CRED45', 'Crédito 45 días', 45, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED45');

UPDATE gen_condicion_pago
SET nombre = 'Crédito 45 días', dias_credito = 45, numero_cuotas = NULL, dia_mes_pago = NULL, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CRED45';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CRED60', 'Crédito 60 días', 60, NULL, NULL, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CRED60');

UPDATE gen_condicion_pago
SET nombre = 'Crédito 60 días', dias_credito = 60, numero_cuotas = NULL, dia_mes_pago = NULL, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CRED60';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CUOT2', '2 cuotas mensuales (día 15)', 0, 2, 15, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT2');

UPDATE gen_condicion_pago
SET nombre = '2 cuotas mensuales (día 15)', dias_credito = 0, numero_cuotas = 2, dia_mes_pago = 15, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CUOT2';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CUOT3', '3 cuotas mensuales (día 15)', 0, 3, 15, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT3');

UPDATE gen_condicion_pago
SET nombre = '3 cuotas mensuales (día 15)', dias_credito = 0, numero_cuotas = 3, dia_mes_pago = 15, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CUOT3';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CUOT4', '4 cuotas mensuales (día 15)', 0, 4, 15, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT4');

UPDATE gen_condicion_pago
SET nombre = '4 cuotas mensuales (día 15)', dias_credito = 0, numero_cuotas = 4, dia_mes_pago = 15, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CUOT4';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CUOT6', '6 cuotas mensuales (día 15)', 0, 6, 15, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT6');

UPDATE gen_condicion_pago
SET nombre = '6 cuotas mensuales (día 15)', dias_credito = 0, numero_cuotas = 6, dia_mes_pago = 15, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CUOT6';

INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
SELECT 'CUOT3F', '3 cuotas mensuales (fin de mes)', 0, 3, 28, 1
WHERE NOT EXISTS (SELECT 1 FROM gen_condicion_pago WHERE UPPER(codigo) = 'CUOT3F');

UPDATE gen_condicion_pago
SET nombre = '3 cuotas mensuales (fin de mes)', dias_credito = 0, numero_cuotas = 3, dia_mes_pago = 28, estado = 1, fecha_modificacion = NOW()
WHERE UPPER(codigo) = 'CUOT3F';
