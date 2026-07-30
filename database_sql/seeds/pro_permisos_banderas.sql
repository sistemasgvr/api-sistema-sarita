-- Permisos y listas del módulo Productos e Inventario (ejecutar después de crear tablas pro_*)

-- ============================================================
-- LISTAS MAESTRAS (gen_lista + gen_lista_opciones)
-- ============================================================

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('UnidadMedida', 'Unidades de medida de productos'),
        ('TipoMovInv', 'Tipos de movimiento de inventario'),
        ('TipoDocumentoRef', 'Tipos de documento origen en movimientos de inventario'),
        ('TipoCatalogoPrecio', 'Tipos de ítem en catálogo de precios')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

-- UnidadMedida
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('UNID', 'Unidad'),
        ('MT3', 'Metro cúbico'),
        ('KG', 'Kilogramo'),
        ('MTS', 'Metro'),
        ('PAR', 'Par'),
        ('LTR', 'Litro'),
        ('GLN', 'Galón')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'UnidadMedida'
  AND NOT EXISTS (
      SELECT 1
      FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id
        AND lo.nombre = v.nombre
  );

-- TipoMovInv (SALIDA resta stock; el resto suma)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('INGRESO', 'Ingreso de mercadería al almacén'),
        ('SALIDA', 'Salida de mercadería del almacén'),
        ('TRASLADO', 'Traslado entre almacenes'),
        ('AJUSTE', 'Ajuste de inventario')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovInv'
  AND NOT EXISTS (
      SELECT 1
      FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id
        AND lo.nombre = v.nombre
  );

-- TipoDocumentoRef
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('FACTURA', 'Factura de venta o compra'),
        ('BOLETA', 'Boleta de venta'),
        ('NOTA_CREDITO', 'Nota de crédito'),
        ('NOTA_DEBITO', 'Nota de débito'),
        ('NOTA_VENTA', 'Venta sin documento / nota de venta interna (no CPE)'),
        ('GRE', 'Guía de remisión electrónica'),
        ('PRESTAMO', 'Préstamo de cilindro'),
        ('ALQUILER', 'Alquiler de cilindro'),
        ('RECARGA', 'Recarga de gas'),
        ('MANTENIMIENTO', 'Mantenimiento de cilindro'),
        ('COMPRA', 'Comprobante de compra'),
        ('DEVOLUCION', 'Devolución de cilindro o mercadería')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoDocumentoRef'
  AND NOT EXISTS (
      SELECT 1
      FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id
        AND lo.nombre = v.nombre
  );

-- TipoCatalogoPrecio
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('RECARGADO', 'Gas con cilindro (recarga vendida)'),
        ('GARANTIA', 'Depósito o garantía de préstamo'),
        ('VENTA_CILINDRO', 'Cilindro vacío vendido'),
        ('ACCESORIO', 'Accesorio o repuesto')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoCatalogoPrecio'
  AND NOT EXISTS (
      SELECT 1
      FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id
        AND lo.nombre = v.nombre
  );

-- ============================================================
-- PERMISOS
-- ============================================================

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
        ('productos.restaurar', 'Restaurar productos eliminados'),
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
