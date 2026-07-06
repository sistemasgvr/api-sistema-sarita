/**
 * Banderas de permiso. El nombre en BD (auth_permisos.nombre) debe coincidir con el valor.
 * auth.todo = acceso total (superadmin).
 */
export const PermisoBanderas = {
  AUTH_TODO: 'auth.todo',

  EJEMPLOS_LISTAR: 'ejemplos.listar',
  EJEMPLOS_VER: 'ejemplos.ver',
  EJEMPLOS_CREAR: 'ejemplos.crear',
  EJEMPLOS_EDITAR: 'ejemplos.editar',
  EJEMPLOS_ELIMINAR: 'ejemplos.eliminar',

  USUARIOS_LISTAR: 'usuarios.listar',
  USUARIOS_VER: 'usuarios.ver',
  USUARIOS_CREAR: 'usuarios.crear',
  USUARIOS_EDITAR: 'usuarios.editar',
  USUARIOS_ELIMINAR: 'usuarios.eliminar',
  USUARIOS_ACTIVAR: 'usuarios.activar',

  ROLES_LISTAR: 'roles.listar',
  ROLES_VER: 'roles.ver',
  ROLES_CREAR: 'roles.crear',
  ROLES_EDITAR: 'roles.editar',
  ROLES_ELIMINAR: 'roles.eliminar',

  PERMISOS_LISTAR: 'permisos.listar',
  PERMISOS_VER: 'permisos.ver',
  PERMISOS_CREAR: 'permisos.crear',
  PERMISOS_EDITAR: 'permisos.editar',
  PERMISOS_ELIMINAR: 'permisos.eliminar',

  USUARIOS_ROLES_LISTAR: 'usuarios_roles.listar',
  USUARIOS_ROLES_ASIGNAR: 'usuarios_roles.asignar',
  USUARIOS_ROLES_QUITAR: 'usuarios_roles.quitar',

  ROLES_PERMISOS_LISTAR: 'roles_permisos.listar',
  ROLES_PERMISOS_ASIGNAR: 'roles_permisos.asignar',
  ROLES_PERMISOS_QUITAR: 'roles_permisos.quitar',

  SESIONES_LISTAR: 'sesiones.listar',
  SESIONES_VER: 'sesiones.ver',
  SESIONES_CREAR: 'sesiones.crear',
  SESIONES_CERRAR: 'sesiones.cerrar',

  CLIENTES_LISTAR: 'clientes.listar',
  CLIENTES_VER: 'clientes.ver',
  CLIENTES_CREAR: 'clientes.crear',
  CLIENTES_EDITAR: 'clientes.editar',
  CLIENTES_ELIMINAR: 'clientes.eliminar',
  CLIENTES_RESTAURAR: 'clientes.restaurar',

  SUCURSALES_LISTAR: 'sucursales.listar',
  SUCURSALES_VER: 'sucursales.ver',
  SUCURSALES_CREAR: 'sucursales.crear',
  SUCURSALES_EDITAR: 'sucursales.editar',
  SUCURSALES_ELIMINAR: 'sucursales.eliminar',

  ALMACENES_LISTAR: 'almacenes.listar',
  ALMACENES_VER: 'almacenes.ver',
  ALMACENES_CREAR: 'almacenes.crear',
  ALMACENES_EDITAR: 'almacenes.editar',
  ALMACENES_ELIMINAR: 'almacenes.eliminar',

  CONDICIONES_PAGO_LISTAR: 'condiciones_pago.listar',
  CONDICIONES_PAGO_VER: 'condiciones_pago.ver',
  CONDICIONES_PAGO_CREAR: 'condiciones_pago.crear',
  CONDICIONES_PAGO_EDITAR: 'condiciones_pago.editar',
  CONDICIONES_PAGO_ELIMINAR: 'condiciones_pago.eliminar',

  EMPRESAS_LISTAR: 'empresas.listar',
  EMPRESAS_VER: 'empresas.ver',
  EMPRESAS_CREAR: 'empresas.crear',
  EMPRESAS_EDITAR: 'empresas.editar',
  EMPRESAS_ELIMINAR: 'empresas.eliminar',

  CONFIGURACION_SUNAT_LISTAR: 'configuracion_sunat.listar',
  CONFIGURACION_SUNAT_VER: 'configuracion_sunat.ver',
  CONFIGURACION_SUNAT_CREAR: 'configuracion_sunat.crear',
  CONFIGURACION_SUNAT_EDITAR: 'configuracion_sunat.editar',
  CONFIGURACION_SUNAT_ELIMINAR: 'configuracion_sunat.eliminar',

  CONFIGURACION_SERVICIOS_LISTAR: 'configuracion_servicios.listar',
  CONFIGURACION_SERVICIOS_VER: 'configuracion_servicios.ver',
  CONFIGURACION_SERVICIOS_CREAR: 'configuracion_servicios.crear',
  CONFIGURACION_SERVICIOS_EDITAR: 'configuracion_servicios.editar',
  CONFIGURACION_SERVICIOS_ELIMINAR: 'configuracion_servicios.eliminar',

  PRODUCTOS_HUB_VER: 'productos.ver',

  CATEGORIAS_LISTAR: 'categorias.listar',
  CATEGORIAS_VER: 'categorias.ver',
  CATEGORIAS_CREAR: 'categorias.crear',
  CATEGORIAS_EDITAR: 'categorias.editar',
  CATEGORIAS_ELIMINAR: 'categorias.eliminar',

  SUB_CATEGORIAS_LISTAR: 'sub_categorias.listar',
  SUB_CATEGORIAS_VER: 'sub_categorias.ver',
  SUB_CATEGORIAS_CREAR: 'sub_categorias.crear',
  SUB_CATEGORIAS_EDITAR: 'sub_categorias.editar',
  SUB_CATEGORIAS_ELIMINAR: 'sub_categorias.eliminar',

  PRODUCTOS_LISTAR: 'productos.listar',
  PRODUCTOS_VER: 'productos.ver',
  PRODUCTOS_CREAR: 'productos.crear',
  PRODUCTOS_EDITAR: 'productos.editar',
  PRODUCTOS_ELIMINAR: 'productos.eliminar',

  CATALOGO_PRECIOS_LISTAR: 'catalogo_precios.listar',
  CATALOGO_PRECIOS_VER: 'catalogo_precios.ver',
  CATALOGO_PRECIOS_CREAR: 'catalogo_precios.crear',
  CATALOGO_PRECIOS_EDITAR: 'catalogo_precios.editar',
  CATALOGO_PRECIOS_ELIMINAR: 'catalogo_precios.eliminar',

  STOCK_LISTAR: 'stock.listar',
  STOCK_VER: 'stock.ver',
  STOCK_CREAR: 'stock.crear',
  STOCK_EDITAR: 'stock.editar',
  STOCK_ELIMINAR: 'stock.eliminar',

  MOVIMIENTOS_LISTAR: 'movimientos.listar',
  MOVIMIENTOS_VER: 'movimientos.ver',
  MOVIMIENTOS_CREAR: 'movimientos.crear',
  MOVIMIENTOS_EDITAR: 'movimientos.editar',
  MOVIMIENTOS_ELIMINAR: 'movimientos.eliminar',
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] = Object.values(
  PermisoBanderas,
);
