-- Permisos que el backend exige (@Permisos) y no existían en auth_permisos.
-- Detectados el 2026-10-06 comparando permiso-banderas.ts contra la base de producción
-- (faltaban también en desarrollo). Sin ellos solo entra quien tiene auth.todo.
-- Idempotente: ajusta la secuencia y salta los que ya existan. No asigna roles.
BEGIN;

SELECT setval('auth_permisos_id_seq', GREATEST((SELECT MAX(id) FROM auth_permisos), 1));

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('actividades.crear', 'Crear actividades'),
        ('actividades.editar', 'Editar actividades'),
        ('actividades.eliminar', 'Eliminar actividades'),
        ('actividades.listar', 'Listar actividades'),
        ('actividades.ver', 'Ver detalle de actividades'),
        ('activo.crear', 'Crear activos'),
        ('activo.editar', 'Editar activos'),
        ('activo.eliminar', 'Eliminar activos'),
        ('activo.listar', 'Listar activos'),
        ('activo.ver', 'Ver detalle de activos'),
        ('catalogos.editar', 'Editar catálogos (listas maestras)'),
        ('choferes.crear', 'Crear choferes'),
        ('choferes.editar', 'Editar choferes'),
        ('choferes.eliminar', 'Eliminar choferes'),
        ('choferes.listar', 'Listar choferes'),
        ('choferes.ver', 'Ver detalle de choferes'),
        ('contactos.crear', 'Crear contactos de clientes'),
        ('contactos.editar', 'Editar contactos de clientes'),
        ('contactos.eliminar', 'Eliminar contactos de clientes'),
        ('contactos.listar', 'Listar contactos de clientes'),
        ('contactos.ver', 'Ver detalle de contactos de clientes'),
        ('cuentas_bancarias.crear', 'Crear cuentas bancarias'),
        ('cuentas_bancarias.editar', 'Editar cuentas bancarias'),
        ('cuentas_bancarias.eliminar', 'Eliminar cuentas bancarias'),
        ('cuentas_bancarias.listar', 'Listar cuentas bancarias'),
        ('cuentas_bancarias.ver', 'Ver detalle de cuentas bancarias'),
        ('dashboard.ver_compras', 'Ver dashboard del módulo Compras'),
        ('dashboard.ver_garantias', 'Ver dashboard del módulo Garantías'),
        ('dashboard.ver_productos', 'Ver dashboard del módulo Productos'),
        ('dashboard.ver_ventas', 'Ver dashboard del módulo Ventas'),
        ('direcciones.crear', 'Crear direcciones de clientes'),
        ('direcciones.editar', 'Editar direcciones de clientes'),
        ('direcciones.eliminar', 'Eliminar direcciones de clientes'),
        ('direcciones.listar', 'Listar direcciones de clientes'),
        ('direcciones.ver', 'Ver detalle de direcciones de clientes'),
        ('documentos_vencimiento.crear', 'Crear permisos y certificados (vencimientos)'),
        ('documentos_vencimiento.editar', 'Editar permisos y certificados (vencimientos)'),
        ('documentos_vencimiento.eliminar', 'Eliminar permisos y certificados (vencimientos)'),
        ('documentos_vencimiento.listar', 'Listar permisos y certificados (vencimientos)'),
        ('documentos_vencimiento.ver', 'Ver detalle de permisos y certificados (vencimientos)'),
        ('inventario_movimientos.crear', 'Crear movimientos de inventario'),
        ('inventario_movimientos.eliminar', 'Eliminar movimientos de inventario'),
        ('inventario_movimientos.listar', 'Listar movimientos de inventario'),
        ('inventario_movimientos.ver', 'Ver detalle de movimientos de inventario'),
        ('licencias.crear', 'Crear licencias de conducir'),
        ('licencias.editar', 'Editar licencias de conducir'),
        ('licencias.eliminar', 'Eliminar licencias de conducir'),
        ('licencias.listar', 'Listar licencias de conducir'),
        ('licencias.ver', 'Ver detalle de licencias de conducir'),
        ('trabajador.crear', 'Crear trabajadores'),
        ('trabajador.editar', 'Editar trabajadores'),
        ('trabajador.eliminar', 'Eliminar trabajadores'),
        ('trabajador.listar', 'Listar trabajadores'),
        ('trabajador.ver', 'Ver detalle de trabajadores'),
        ('vehiculos.crear', 'Crear vehículos'),
        ('vehiculos.editar', 'Editar vehículos'),
        ('vehiculos.eliminar', 'Eliminar vehículos'),
        ('vehiculos.listar', 'Listar vehículos'),
        ('vehiculos.ver', 'Ver detalle de vehículos')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre);

COMMIT;
