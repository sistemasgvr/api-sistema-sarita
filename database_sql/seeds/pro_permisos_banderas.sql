-- Permisos del módulo Productos e Inventario (ejecutar después de crear tablas pro_*)

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('productos.ver', 'Acceso al hub de productos e inventario'),
        ('categorias.listar', 'Listar categorías de producto'),
        ('categorias.ver', 'Ver detalle de categoría'),
        ('categorias.crear', 'Crear categorías de producto'),
        ('categorias.editar', 'Editar categorías de producto'),
        ('categorias.eliminar', 'Eliminar categorías de producto'),
        ('sub_categorias.listar', 'Listar subcategorías de producto'),
        ('sub_categorias.ver', 'Ver detalle de subcategoría'),
        ('sub_categorias.crear', 'Crear subcategorías de producto'),
        ('sub_categorias.editar', 'Editar subcategorías de producto'),
        ('sub_categorias.eliminar', 'Eliminar subcategorías de producto'),
        ('productos.listar', 'Listar productos'),
        ('productos.ver', 'Ver detalle de producto'),
        ('productos.crear', 'Crear productos'),
        ('productos.editar', 'Editar productos'),
        ('productos.eliminar', 'Eliminar productos'),
        ('catalogo_precios.listar', 'Listar catálogo de precios'),
        ('catalogo_precios.ver', 'Ver detalle de catálogo de precios'),
        ('catalogo_precios.crear', 'Crear ítems de catálogo de precios'),
        ('catalogo_precios.editar', 'Editar catálogo de precios'),
        ('catalogo_precios.eliminar', 'Eliminar ítems de catálogo de precios'),
        ('stock.listar', 'Listar stock por almacén'),
        ('stock.ver', 'Ver detalle de stock'),
        ('stock.crear', 'Registrar stock inicial'),
        ('stock.editar', 'Ajustar stock mínimo o cantidad'),
        ('stock.eliminar', 'Eliminar registro de stock'),
        ('movimientos.listar', 'Listar movimientos de inventario (kardex)'),
        ('movimientos.ver', 'Ver detalle de movimiento'),
        ('movimientos.crear', 'Registrar movimientos de inventario'),
        ('movimientos.editar', 'Editar glosa o referencia de movimiento'),
        ('movimientos.eliminar', 'Anular movimientos de inventario')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

-- Asignar permisos de productos e inventario al rol Administrador
INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND (
      p.nombre = 'productos.ver'
      OR p.nombre LIKE 'categorias.%'
      OR p.nombre LIKE 'sub_categorias.%'
      OR p.nombre LIKE 'productos.%'
      OR p.nombre LIKE 'catalogo_precios.%'
      OR p.nombre LIKE 'stock.%'
      OR p.nombre LIKE 'movimientos.%'
  )
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
