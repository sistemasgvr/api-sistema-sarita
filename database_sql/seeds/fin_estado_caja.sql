-- Opciones de la lista EstadoCaja (ABIERTA / CERRADA).
-- También en migración 20260811_fin_caja_libro_diario.sql.
-- Idempotente.

INSERT INTO gen_lista (nombre, descripcion)
SELECT 'EstadoCaja', 'Estado de sesión de caja diaria'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'EstadoCaja');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ABIERTA', 'Caja abierta / en operación'),
        ('CERRADA', 'Caja cerrada / arqueo finalizado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoCaja'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );
