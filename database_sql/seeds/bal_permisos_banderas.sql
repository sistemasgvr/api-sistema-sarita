-- Permisos del módulo Balones / Cilindros (ejecutar después de bal_lista_opciones.sql)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('balones.ver', 'Acceso al hub de balones y cilindros'),
        ('tipos_balon.listar', 'Listar tipos de balón'),
        ('tipos_balon.ver', 'Ver detalle de tipo de balón'),
        ('tipos_balon.crear', 'Crear tipos de balón'),
        ('tipos_balon.editar', 'Editar tipos de balón'),
        ('tipos_balon.eliminar', 'Eliminar tipos de balón'),
        ('balones.listar', 'Listar balones / cilindros'),
        ('balones.ver', 'Ver detalle de balón'),
        ('balones.crear', 'Registrar balones'),
        ('balones.editar', 'Editar balones'),
        ('balones.eliminar', 'Eliminar balones'),
        ('movimientos_balon.listar', 'Listar movimientos de balón'),
        ('movimientos_balon.ver', 'Ver detalle de movimiento de balón'),
        ('movimientos_balon.crear', 'Registrar movimientos de balón'),
        ('movimientos_balon.editar', 'Editar movimientos de balón'),
        ('movimientos_balon.eliminar', 'Anular movimientos de balón'),
        ('movimientos_recarga.listar', 'Listar movimientos de recarga'),
        ('movimientos_recarga.ver', 'Ver detalle de movimiento de recarga'),
        ('movimientos_recarga.crear', 'Registrar movimientos de recarga'),
        ('movimientos_recarga.editar', 'Editar movimientos de recarga'),
        ('movimientos_recarga.eliminar', 'Anular movimientos de recarga'),
        ('prestamos_balon.listar', 'Listar préstamos de cilindros'),
        ('prestamos_balon.ver', 'Ver detalle de préstamo'),
        ('prestamos_balon.crear', 'Crear préstamos de cilindros'),
        ('prestamos_balon.editar', 'Editar préstamos de cilindros'),
        ('prestamos_balon.eliminar', 'Eliminar préstamos de cilindros'),
        ('prestamos_detalle.listar', 'Listar detalle de préstamos'),
        ('prestamos_detalle.ver', 'Ver detalle por cilindro en préstamo'),
        ('prestamos_detalle.crear', 'Agregar cilindros a préstamo'),
        ('prestamos_detalle.editar', 'Editar detalle de préstamo'),
        ('prestamos_detalle.eliminar', 'Eliminar detalle de préstamo'),
        ('alquileres_balon.listar', 'Listar alquileres de regulador/accesorio'),
        ('alquileres_balon.ver', 'Ver detalle de alquiler'),
        ('alquileres_balon.crear', 'Crear alquileres de regulador/accesorio'),
        ('alquileres_balon.editar', 'Editar alquileres de regulador/accesorio'),
        ('alquileres_balon.eliminar', 'Eliminar alquileres de regulador/accesorio'),
        ('alquileres_detalle.listar', 'Listar cilindros vinculados a alquiler'),
        ('alquileres_detalle.ver', 'Ver vínculo cilindro-alquiler'),
        ('alquileres_detalle.crear', 'Vincular cilindros a alquiler (legado; preferir préstamo)'),
        ('alquileres_detalle.editar', 'Editar vínculo cilindro-alquiler'),
        ('alquileres_detalle.eliminar', 'Eliminar vínculo cilindro-alquiler'),
        ('mantenimientos_balon.listar', 'Listar mantenimientos de cilindros'),
        ('mantenimientos_balon.ver', 'Ver detalle de mantenimiento'),
        ('mantenimientos_balon.crear', 'Registrar mantenimientos'),
        ('mantenimientos_balon.editar', 'Editar mantenimientos'),
        ('mantenimientos_balon.eliminar', 'Eliminar mantenimientos'),
        ('bajas_balon.listar', 'Listar solicitudes de baja de cilindro'),
        ('bajas_balon.ver', 'Ver detalle de solicitud de baja de cilindro'),
        ('bajas_balon.solicitar', 'Solicitar baja de cilindro'),
        ('bajas_balon.aprobar', 'Aprobar solicitudes de baja de cilindro'),
        ('bajas_balon.rechazar', 'Rechazar solicitudes de baja de cilindro')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND (
      p.nombre = 'balones.ver'
      OR p.nombre LIKE 'tipos_balon.%'
      OR p.nombre LIKE 'balones.%'
      OR p.nombre LIKE 'movimientos_balon.%'
      OR p.nombre LIKE 'movimientos_recarga.%'
      OR p.nombre LIKE 'prestamos_balon.%'
      OR p.nombre LIKE 'prestamos_detalle.%'
      OR p.nombre LIKE 'alquileres_balon.%'
      OR p.nombre LIKE 'alquileres_detalle.%'
      OR p.nombre LIKE 'mantenimientos_balon.%'
      OR p.nombre LIKE 'bajas_balon.%'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
