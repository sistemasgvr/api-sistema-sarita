-- Permisos del módulo productos
INSERT INTO
  auth_permisos (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      (
        'productos.ver',
        'Acceso al hub de productos e inventario',
        TRUE
      ),
      (
        'categorias.listar',
        'Listar categorías de producto',
        TRUE
      ),
      (
        'categorias.ver',
        'Ver detalle de categoría',
        TRUE
      ),
      (
        'categorias.crear',
        'Crear categorías de producto',
        TRUE
      ),
      (
        'categorias.editar',
        'Editar categorías de producto',
        TRUE
      ),
      (
        'categorias.eliminar',
        'Eliminar categorías de producto',
        TRUE
      ),
      (
        'sub_categorias.listar',
        'Listar subcategorías de producto',
        TRUE
      ),
      (
        'sub_categorias.ver',
        'Ver detalle de subcategoría',
        TRUE
      ),
      (
        'sub_categorias.crear',
        'Crear subcategorías de producto',
        TRUE
      ),
      (
        'sub_categorias.editar',
        'Editar subcategorías de producto',
        TRUE
      ),
      (
        'sub_categorias.eliminar',
        'Eliminar subcategorías de producto',
        TRUE
      ),
      ('productos.listar', 'Listar productos', TRUE),
      ('productos.crear', 'Crear productos', TRUE),
      ('productos.editar', 'Editar productos', TRUE),
      ('productos.eliminar', 'Eliminar productos', TRUE),
      (
        'catalogo_precios.listar',
        'Listar catálogo de precios',
        TRUE
      ),
      (
        'catalogo_precios.ver',
        'Ver detalle de catálogo de precios',
        TRUE
      ),
      (
        'catalogo_precios.crear',
        'Crear ítems de catálogo de precios',
        TRUE
      ),
      (
        'catalogo_precios.editar',
        'Editar catálogo de precios',
        TRUE
      ),
      (
        'catalogo_precios.eliminar',
        'Eliminar ítems de catálogo de precios',
        TRUE
      ),
      ('stock.listar', 'Listar stock por almacén', TRUE),
      ('stock.ver', 'Ver detalle de stock', TRUE),
      ('stock.crear', 'Registrar stock inicial', TRUE),
      (
        'stock.editar',
        'Ajustar stock mínimo o cantidad',
        TRUE
      ),
      (
        'stock.eliminar',
        'Eliminar registro de stock',
        TRUE
      ),
      (
        'movimientos.listar',
        'Listar movimientos de inventario (kardex)',
        TRUE
      ),
      (
        'movimientos.ver',
        'Ver detalle de movimiento',
        TRUE
      ),
      (
        'movimientos.crear',
        'Registrar movimientos de inventario',
        TRUE
      ),
      (
        'movimientos.editar',
        'Editar glosa o referencia de movimiento',
        TRUE
      ),
      (
        'movimientos.eliminar',
        'Anular movimientos de inventario',
        TRUE
      ),
      (
        'productos.restaurar',
        'Restaurar productos eliminados',
        TRUE
      ),
      (
        'stock.restaurar',
        'Restaurar registros de stock eliminados',
        TRUE
      ),
      (
        'sub_categorias.restaurar',
        'Restaurar subcategorías de producto eliminadas',
        TRUE
      ),
      (
        'categorias.restaurar',
        'Restaurar categorías de producto eliminadas',
        TRUE
      )
  ) AS v (nombre, descripcion, estado)
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      auth_permisos p
    WHERE
      p.nombre = v.nombre
  );
