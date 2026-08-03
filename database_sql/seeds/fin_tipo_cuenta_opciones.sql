-- Lista TipoCuentaFinanciera y sus opciones (usadas por todo el módulo de finanzas
-- y el dashboard de clientes con deuda). Sin esto, TODAS las funciones fin_*
-- devuelven "Tipo de cuenta inválido (COBRAR / PAGAR)".
-- Idempotente: se puede correr varias veces sin duplicar.

-- 1. Crear la LISTA si no existe (gen_lista.nombre no tiene UNIQUE constraint,
--    así que usamos NOT EXISTS).
INSERT INTO gen_lista (nombre, descripcion)
SELECT 'TipoCuentaFinanciera', 'COBRAR (cliente) o PAGAR (proveedor)'
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista WHERE nombre = 'TipoCuentaFinanciera'
);

-- 2. Sembrar las OPCIONES si no existen
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('COBRAR', 'Cuenta por cobrar (cliente / tercero deudor)'),
        ('PAGAR',  'Cuenta por pagar (proveedor / acreedor)')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoCuentaFinanciera'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
