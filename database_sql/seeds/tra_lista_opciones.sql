-- Catálogos del módulo Trabajadores (Padrón de Personal - RR.HH.)
-- Ejecutar después de gen_lista / gen_lista_opciones base

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('AREAS_TRABAJADOR', 'Áreas laborales del padrón de personal'),
        ('CARGOS_TRABAJADOR', 'Cargos laborales del padrón de personal')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

-- Áreas
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('OPERACIONES', 'Operaciones'),
        ('ADMINISTRACION', 'Administración'),
        ('VENTAS', 'Ventas'),
        ('LOGISTICA', 'Logística'),
        ('CONTABILIDAD', 'Contabilidad')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'AREAS_TRABAJADOR'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.nombre = v.nombre
  );

-- Cargos
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('AUXILIAR', 'Auxiliar'),
        ('SUPERVISOR', 'Supervisor'),
        ('TECNICO', 'Técnico'),
        ('VENDEDOR', 'Vendedor'),
        ('GERENTE', 'Gerente'),
        ('CONDUCTOR', 'Conductor')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'CARGOS_TRABAJADOR'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.nombre = v.nombre
  );
