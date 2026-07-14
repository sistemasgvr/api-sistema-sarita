-- Roles operativos (ejecutar DESPUÉS de todos los seeds de permisos:
--   auth_permisos_banderas.sql, cli_*, gen_*, pro_*, bal_*, ven_*)
--
-- Roles:
--   Administrador  → ya se crea en auth_permisos_banderas.sql (todos los permisos)
--   Vendedor       → mostrador, clientes, comprobantes, POS (recarga/alquiler/mantenimiento)
--   Chofer         → entregas y préstamos de cilindros
--   Operario       → taller / almacén (balones, recargas, mantenimientos, stock)
--   Supervisor     → operario + lectura amplia (sin auth ni configuración de empresa)

-- ============================================================
-- Crear roles
-- ============================================================

INSERT INTO auth_roles (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('Vendedor', 'Mostrador y ventas: clientes, comprobantes y operaciones POS'),
        ('Chofer', 'Entregas: clientes, préstamos y movimientos de cilindros'),
        ('Operario', 'Taller y almacén: cilindros, recargas, mantenimientos e inventario'),
        ('Supervisor', 'Supervisión operativa: mismo alcance que operario con más consulta')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_roles r WHERE r.nombre = v.nombre
);

-- ============================================================
-- Vendedor
-- ============================================================

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Vendedor'
  AND r.estado = TRUE
  AND p.estado = TRUE
  AND (
      p.nombre IN (
          'ventas.ver',
          'productos.ver',
          'balones.ver',
          'almacenes.listar',
          'almacenes.ver',
          'condiciones_pago.listar',
          'condiciones_pago.ver',
          'catalogo_precios.listar',
          'catalogo_precios.ver',
          'stock.listar',
          'stock.ver',
          'productos.listar',
          'tipos_balon.listar',
          'tipos_balon.ver'
      )
      OR p.nombre IN (
          'clientes.listar',
          'clientes.ver',
          'clientes.crear',
          'clientes.editar'
      )
      OR p.nombre LIKE 'comprobantes.%'
      OR p.nombre LIKE 'movimientos_recarga.%'
      OR p.nombre LIKE 'alquileres_balon.%'
      OR p.nombre LIKE 'alquileres_detalle.%'
      OR p.nombre LIKE 'mantenimientos_balon.%'
      OR p.nombre IN (
          'balones.listar',
          'balones.ver',
          'balones.crear'
      )
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );

-- ============================================================
-- Chofer
-- ============================================================

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Chofer'
  AND r.estado = TRUE
  AND p.estado = TRUE
  AND (
      p.nombre IN (
          'balones.ver',
          'clientes.listar',
          'clientes.ver',
          'balones.listar',
          'balones.ver',
          'tipos_balon.listar',
          'tipos_balon.ver',
          'almacenes.listar',
          'almacenes.ver'
      )
      OR p.nombre LIKE 'movimientos_balon.%'
      OR p.nombre LIKE 'prestamos_balon.%'
      OR p.nombre LIKE 'prestamos_detalle.%'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );

-- ============================================================
-- Operario
-- ============================================================

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Operario'
  AND r.estado = TRUE
  AND p.estado = TRUE
  AND (
      p.nombre IN (
          'balones.ver',
          'productos.ver',
          'almacenes.listar',
          'almacenes.ver',
          'productos.listar',
          'productos.ver',
          'stock.listar',
          'stock.ver',
          'stock.crear',
          'stock.editar',
          'movimientos.listar',
          'movimientos.ver',
          'movimientos.crear',
          'catalogo_precios.listar',
          'catalogo_precios.ver',
          'tipos_balon.listar',
          'tipos_balon.ver'
      )
      OR p.nombre LIKE 'balones.%'
      OR p.nombre LIKE 'movimientos_balon.%'
      OR p.nombre LIKE 'movimientos_recarga.%'
      OR p.nombre LIKE 'mantenimientos_balon.%'
      OR p.nombre LIKE 'prestamos_balon.%'
      OR p.nombre LIKE 'prestamos_detalle.%'
      OR p.nombre LIKE 'alquileres_balon.%'
      OR p.nombre LIKE 'alquileres_detalle.%'
  )
  AND p.nombre NOT IN (
      'balones.eliminar',
      'tipos_balon.crear',
      'tipos_balon.editar',
      'tipos_balon.eliminar',
      'prestamos_balon.eliminar',
      'alquileres_balon.eliminar',
      'movimientos_balon.eliminar',
      'movimientos_recarga.eliminar',
      'mantenimientos_balon.eliminar'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );

-- ============================================================
-- Supervisor (operario + catálogos de lectura + sin anulaciones críticas)
-- ============================================================

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Supervisor'
  AND r.estado = TRUE
  AND p.estado = TRUE
  AND (
      p.nombre IN (
          'balones.ver',
          'productos.ver',
          'ventas.ver',
          'clientes.listar',
          'clientes.ver',
          'comprobantes.listar',
          'comprobantes.ver',
          'comprobantes.consultar_cdr',
          'almacenes.listar',
          'almacenes.ver',
          'sucursales.listar',
          'sucursales.ver',
          'condiciones_pago.listar',
          'condiciones_pago.ver',
          'productos.listar',
          'productos.ver',
          'categorias.listar',
          'categorias.ver',
          'sub_categorias.listar',
          'sub_categorias.ver',
          'catalogo_precios.listar',
          'catalogo_precios.ver',
          'stock.listar',
          'stock.ver',
          'stock.crear',
          'stock.editar',
          'movimientos.listar',
          'movimientos.ver',
          'movimientos.crear',
          'tipos_balon.listar',
          'tipos_balon.ver'
      )
      OR p.nombre LIKE 'balones.%'
      OR p.nombre LIKE 'movimientos_balon.%'
      OR p.nombre LIKE 'movimientos_recarga.%'
      OR p.nombre LIKE 'mantenimientos_balon.%'
      OR p.nombre LIKE 'prestamos_balon.%'
      OR p.nombre LIKE 'prestamos_detalle.%'
      OR p.nombre LIKE 'alquileres_balon.%'
      OR p.nombre LIKE 'alquileres_detalle.%'
  )
  AND p.nombre NOT IN (
      'tipos_balon.eliminar',
      'balones.eliminar'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );

-- Nota: la aprobación de bajas de cilindros sigue restringida al rol
-- "Administrador" en bal_aprobar_baja_balon / bal_rechazar_baja_balon.
