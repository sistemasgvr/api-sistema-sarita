-- Catálogos del módulo Activos (Inventario de activos fijos de la empresa)
-- Ejecutar después de gen_lista / gen_lista_opciones base

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('ACTIVOS_TIPO', 'Tipos de activo fijo de la empresa (Computadoras/Laptops, Escritorios)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

-- Tipos de activo
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('COMPUTADORAS_LAPTOPS', 'Computadoras / Laptops'),
        ('ESCRITORIOS', 'Escritorios')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'ACTIVOS_TIPO'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.nombre = v.nombre
  );
