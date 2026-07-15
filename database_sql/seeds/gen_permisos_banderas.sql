-- Permisos de catálogos generales (ejecutar después de crear tablas gen_*)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('configuracion.ver', 'Acceso al hub de configuración'),
        ('sucursales.listar', 'Listar sucursales'),
        ('sucursales.ver', 'Ver detalle de sucursal'),
        ('sucursales.crear', 'Crear sucursales'),
        ('sucursales.editar', 'Editar sucursales'),
        ('sucursales.eliminar', 'Eliminar sucursales'),
        ('actividades.listar',   'Listar actividades'),
        ('actividades.ver',      'Ver detalle de actividad'),
        ('actividades.crear',    'Crear actividades'),
        ('actividades.editar',   'Editar actividades'),
        ('actividades.eliminar', 'Eliminar actividades');
        ('almacenes.listar', 'Listar almacenes'),
        ('almacenes.ver', 'Ver detalle de almacén'),
        ('almacenes.crear', 'Crear almacenes'),
        ('almacenes.editar', 'Editar almacenes'),
        ('almacenes.eliminar', 'Eliminar almacenes'),
        ('condiciones_pago.listar', 'Listar condiciones de pago'),
        ('condiciones_pago.ver', 'Ver detalle de condición de pago'),
        ('condiciones_pago.crear', 'Crear condiciones de pago'),
        ('condiciones_pago.editar', 'Editar condiciones de pago'),
        ('condiciones_pago.eliminar', 'Eliminar condiciones de pago'),
        ('empresas.listar', 'Listar empresas'),
        ('empresas.ver', 'Ver detalle de empresa'),
        ('empresas.crear', 'Crear empresas'),
        ('empresas.editar', 'Editar empresas'),
        ('empresas.eliminar', 'Eliminar empresas'),
        ('configuracion_sunat.listar', 'Listar configuraciones SUNAT'),
        ('configuracion_sunat.ver', 'Ver detalle de configuración SUNAT'),
        ('configuracion_sunat.crear', 'Crear configuraciones SUNAT'),
        ('configuracion_sunat.editar', 'Editar configuraciones SUNAT'),
        ('configuracion_sunat.eliminar', 'Eliminar configuraciones SUNAT'),
        ('configuracion_servicios.listar', 'Listar configuraciones de servicios'),
        ('configuracion_servicios.ver', 'Ver detalle de configuración de servicio'),
        ('configuracion_servicios.crear', 'Crear configuraciones de servicios'),
        ('configuracion_servicios.editar', 'Editar configuraciones de servicios'),
        ('configuracion_servicios.eliminar', 'Eliminar configuraciones de servicios')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de configuración al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND (
      p.nombre = 'configuracion.ver'
      OR p.nombre LIKE 'sucursales.%'
      OR p.nombre LIKE 'almacenes.%'
      OR p.nombre LIKE 'condiciones_pago.%'
      OR p.nombre LIKE 'empresas.%'
      OR p.nombre LIKE 'configuracion_sunat.%'
      OR p.nombre LIKE 'configuracion_servicios.%'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
