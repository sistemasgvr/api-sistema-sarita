-- Permisos del módulo Ventas / Comprobantes (ejecutar después de ven_lista_opciones.sql)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('ventas.ver', 'Acceso al módulo de ventas y facturación'),
        ('comprobantes.listar', 'Listar comprobantes de venta'),
        ('comprobantes.ver', 'Ver detalle de comprobante'),
        ('comprobantes.crear', 'Crear comprobantes de venta'),
        ('comprobantes.editar', 'Editar comprobantes pendientes'),
        ('comprobantes.eliminar', 'Anular comprobantes pendientes'),
        ('comprobantes.emitir', 'Emitir comprobante electrónico ante SUNAT'),
        ('comprobantes.consultar_cdr', 'Consultar CDR / estado SUNAT')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);
