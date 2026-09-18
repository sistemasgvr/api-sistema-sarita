-- Catálogos SUNAT para comprobantes de percepción (catálogo 22) y retención
-- (catálogo 23). Igual que TipoGuiaRemision: el código SUNAT va en
-- `descripcion` y la etiqueta en `nombre` (gen_lista_opciones no tiene
-- columnas codigo/orden).

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('RegimenPercepcion', 'Catálogo 22 SUNAT — régimen de percepción (código en descripcion)'),
        ('RegimenRetencion', 'Catálogo 23 SUNAT — régimen de retención (código en descripcion)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre);

-- Catálogo 22: régimen de percepción. El nombre no lleva la tasa: esa vive en
-- la lista TasaPercepcion, asociada al régimen por su código.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', 'Percepción venta interna'),
    ('02', 'Percepción a la adquisición de combustible'),
    ('03', 'Percepción realizada al agente de percepción con tasa especial')
) AS v(codigo, nombre)
WHERE l.nombre = 'RegimenPercepcion'
  AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones o WHERE o.id_lista = l.id AND o.descripcion = v.codigo);

-- Catálogo 23: régimen de retención.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', 'Régimen general'),
    ('02', 'Régimen con tasa especial')
) AS v(codigo, nombre)
WHERE l.nombre = 'RegimenRetencion'
  AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones o WHERE o.id_lista = l.id AND o.descripcion = v.codigo);

-- Instalaciones anteriores guardaron el porcentaje dentro del nombre del
-- régimen («Percepción venta interna (2%)»). Ahora la tasa es un dato aparte.
UPDATE gen_lista_opciones o
SET nombre = v.nombre, fecha_modificacion = now()
FROM gen_lista l, (VALUES
    ('RegimenPercepcion', '01', 'Percepción venta interna'),
    ('RegimenPercepcion', '02', 'Percepción a la adquisición de combustible'),
    ('RegimenPercepcion', '03', 'Percepción realizada al agente de percepción con tasa especial'),
    ('RegimenRetencion', '01', 'Régimen general'),
    ('RegimenRetencion', '02', 'Régimen con tasa especial')
) AS v(lista, codigo, nombre)
WHERE l.id = o.id_lista AND l.nombre = v.lista AND TRIM(o.descripcion) = v.codigo
  AND o.nombre IS DISTINCT FROM v.nombre;

-- Tasas por régimen. `descripcion` es el código del régimen al que aplican y
-- `nombre` el porcentaje; un régimen puede tener más de una tasa vigente.
INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TasaPercepcion', 'Tasas de percepción por régimen (código del régimen en descripcion)'),
        ('TasaRetencion', 'Tasas de retención por régimen (código del régimen en descripcion)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.tasa, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', '2%'),
    ('02', '1%'),
    ('03', '0.5%')
) AS v(codigo, tasa)
WHERE l.nombre = 'TasaPercepcion'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.descripcion = v.codigo AND o.nombre = v.tasa
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.tasa, v.codigo
FROM gen_lista l
CROSS JOIN (VALUES
    ('01', '3%'),
    ('02', '6%')
) AS v(codigo, tasa)
WHERE l.nombre = 'TasaRetencion'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones o
      WHERE o.id_lista = l.id AND o.descripcion = v.codigo AND o.nombre = v.tasa
  );

-- Permisos de ambos módulos (mismo patrón que doc_permisos_banderas.sql).
INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('percepciones.listar', 'Listar comprobantes de percepción'),
        ('percepciones.ver', 'Ver detalle de un comprobante de percepción'),
        ('percepciones.crear', 'Crear comprobantes de percepción'),
        ('percepciones.editar', 'Editar comprobantes de percepción'),
        ('percepciones.eliminar', 'Anular comprobantes de percepción'),
        ('percepciones.emitir', 'Emitir percepciones a SUNAT y descargar PDF/XML oficial'),
        ('retenciones.listar', 'Listar comprobantes de retención'),
        ('retenciones.ver', 'Ver detalle de un comprobante de retención'),
        ('retenciones.crear', 'Crear comprobantes de retención'),
        ('retenciones.editar', 'Editar comprobantes de retención'),
        ('retenciones.eliminar', 'Anular comprobantes de retención'),
        ('retenciones.emitir', 'Emitir retenciones a SUNAT y descargar PDF/XML oficial')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND (p.nombre LIKE 'percepciones.%' OR p.nombre LIKE 'retenciones.%')
  AND NOT EXISTS (SELECT 1 FROM auth_roles_permisos rp WHERE rp.id_rol = r.id AND rp.id_permiso = p.id);
