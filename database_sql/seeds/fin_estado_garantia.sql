-- Opciones de la lista EstadoGarantia (ACTIVA / DEVUELTA).
-- Idempotente.

INSERT INTO gen_lista (nombre, descripcion)
SELECT 'EstadoGarantia', 'Estado de una garantía: ACTIVA (recibida) o DEVUELTA (reembolsada)'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'EstadoGarantia');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ACTIVA',   'Garantía vigente, aún no reembolsada'),
        ('DEVUELTA', 'Garantía ya reembolsada al cliente')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoGarantia'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
