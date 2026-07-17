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
        ('comprobantes.consultar_cdr', 'Consultar CDR / estado SUNAT'),
        ('guias_remision.listar', 'Listar guías de remisión'),
        ('guias_remision.ver', 'Ver detalle de guía de remisión'),
        ('guias_remision.crear', 'Crear guías de remisión'),
        ('guias_remision.editar', 'Editar guías de remisión'),
        ('guias_remision.eliminar', 'Eliminar guías de remisión'),
        ('guias_remision.emitir', 'Emitir / consultar estado SUNAT de GRE')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);
