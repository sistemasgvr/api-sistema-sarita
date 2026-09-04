-- Configuración de comportamiento de cada medio de pago (Fase 3).
--
-- Reproduce exactamente lo que antes estaba escrito a mano dentro de
-- fin_caja_calcular_totales (EFECTIVO / YAPE / PLIN afectan caja) y añade la
-- exigencia de cuenta bancaria y de número de operación.
--
--   es_efectivo               -> billetes y monedas en el cajón.
--   afecta_caja               -> entra al arqueo de la sesión de caja.
--   requiere_cuenta_bancaria  -> exige id_cuenta_bancaria de la empresa.
--   requiere_numero_operacion -> exige número de operación / voucher.
--   es_credito                -> no mueve dinero todavía (queda como CxC).
--
-- Un medio de MedioPago sin fila aquí hace fallar fin_medio_pago_flag con un
-- mensaje explícito: es deliberado, para que un medio nuevo no quede fuera del
-- arqueo en silencio. Si añades uno al catálogo, añádelo también aquí.
--
-- Idempotente: no pisa configuraciones ya ajustadas a mano.

INSERT INTO fin_medio_pago_config (
    id_medio_pago, es_efectivo, afecta_caja, requiere_cuenta_bancaria,
    requiere_numero_operacion, es_credito, orden
)
SELECT o.id, v.es_efectivo, v.afecta_caja, v.requiere_cuenta, v.requiere_op, v.es_credito, v.orden
FROM (
    VALUES
        ('EFECTIVO',      TRUE,  TRUE,  FALSE, FALSE, FALSE, 10),
        ('YAPE',          FALSE, TRUE,  TRUE,  TRUE,  FALSE, 20),
        ('PLIN',          FALSE, TRUE,  TRUE,  TRUE,  FALSE, 30),
        ('TRANSFERENCIA', FALSE, FALSE, TRUE,  TRUE,  FALSE, 40),
        ('DEPOSITO',      FALSE, FALSE, TRUE,  TRUE,  FALSE, 50),
        ('TARJETA',       FALSE, FALSE, TRUE,  FALSE, FALSE, 60),
        ('CHEQUE',        FALSE, FALSE, TRUE,  TRUE,  FALSE, 70),
        ('CREDITO',       FALSE, FALSE, FALSE, FALSE, TRUE,  80)
) AS v(nombre, es_efectivo, afecta_caja, requiere_cuenta, requiere_op, es_credito, orden)
JOIN gen_lista l ON l.nombre = 'MedioPago'
JOIN gen_lista_opciones o ON o.id_lista = l.id AND UPPER(o.nombre) = v.nombre
WHERE NOT EXISTS (
    SELECT 1 FROM fin_medio_pago_config c WHERE c.id_medio_pago = o.id
);
