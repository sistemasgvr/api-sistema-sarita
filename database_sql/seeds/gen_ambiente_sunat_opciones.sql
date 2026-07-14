-- Lista y opciones de ambiente SUNAT (idempotente)

INSERT INTO gen_lista (nombre, descripcion)
SELECT 'AmbienteSunat', 'Ambientes de facturación electrónica SUNAT'
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = 'AmbienteSunat'
);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('Desarrollo', 'Ambiente de desarrollo SUNAT (beta)'),
        ('Producción', 'Ambiente de producción SUNAT')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'AmbienteSunat'
  AND NOT EXISTS (
      SELECT 1
      FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id
        AND lo.nombre = v.nombre
  );
