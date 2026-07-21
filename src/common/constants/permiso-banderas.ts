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

  CONTACTOS_LISTAR: 'contactos.listar',
  CONTACTOS_VER: 'contactos.ver',
  CONTACTOS_CREAR: 'contactos.crear',
  CONTACTOS_EDITAR: 'contactos.editar',
  CONTACTOS_ELIMINAR: 'contactos.eliminar',

  SUCURSALES_LISTAR: 'sucursales.listar',
  SUCURSALES_VER: 'sucursales.ver',
  SUCURSALES_CREAR: 'sucursales.crear',
  SUCURSALES_EDITAR: 'sucursales.editar',
  SUCURSALES_ELIMINAR: 'sucursales.eliminar',

  ACTIVIDADES_LISTAR: 'actividades.listar',
  ACTIVIDADES_VER: 'actividades.ver',
  ACTIVIDADES_CREAR: 'actividades.crear',
  ACTIVIDADES_EDITAR: 'actividades.editar',
  ACTIVIDADES_ELIMINAR: 'actividades.eliminar',

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

  DIRECCIONES_LISTAR: 'direcciones.listar',
  DIRECCIONES_VER: 'direcciones.ver',
  DIRECCIONES_CREAR: 'direcciones.crear',
  DIRECCIONES_EDITAR: 'direcciones.editar',
  DIRECCIONES_ELIMINAR: 'direcciones.eliminar',

  CHOFERES_LISTAR: 'choferes.listar',
  CHOFERES_VER: 'choferes.ver',
  CHOFERES_CREAR: 'choferes.crear',
  CHOFERES_EDITAR: 'choferes.editar',
  CHOFERES_ELIMINAR: 'choferes.eliminar',

  VEHICULOS_LISTAR: 'vehiculos.listar',
  VEHICULOS_VER: 'vehiculos.ver',
  VEHICULOS_CREAR: 'vehiculos.crear',
  VEHICULOS_EDITAR: 'vehiculos.editar',
  VEHICULOS_ELIMINAR: 'vehiculos.eliminar',

  LICENCIAS_LISTAR: 'licencias.listar',
  LICENCIAS_VER: 'licencias.ver',
  LICENCIAS_CREAR: 'licencias.crear',
  LICENCIAS_EDITAR: 'licencias.editar',
  LICENCIAS_ELIMINAR: 'licencias.eliminar',

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
  PRODUCTOS_RESTAURAR: 'productos.restaurar',

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

  BALONES_HUB_VER: 'balones.ver',

  TIPOS_BALON_LISTAR: 'tipos_balon.listar',
  TIPOS_BALON_VER: 'tipos_balon.ver',
  TIPOS_BALON_CREAR: 'tipos_balon.crear',
  TIPOS_BALON_EDITAR: 'tipos_balon.editar',
  TIPOS_BALON_ELIMINAR: 'tipos_balon.eliminar',

  BALONES_LISTAR: 'balones.listar',
  BALONES_VER: 'balones.ver',
  BALONES_CREAR: 'balones.crear',
  BALONES_EDITAR: 'balones.editar',
  BALONES_ELIMINAR: 'balones.eliminar',

  MOVIMIENTOS_BALON_LISTAR: 'movimientos_balon.listar',
  MOVIMIENTOS_BALON_VER: 'movimientos_balon.ver',
  MOVIMIENTOS_BALON_CREAR: 'movimientos_balon.crear',
  MOVIMIENTOS_BALON_EDITAR: 'movimientos_balon.editar',
  MOVIMIENTOS_BALON_ELIMINAR: 'movimientos_balon.eliminar',

  MOVIMIENTOS_RECARGA_LISTAR: 'movimientos_recarga.listar',
  MOVIMIENTOS_RECARGA_VER: 'movimientos_recarga.ver',
  MOVIMIENTOS_RECARGA_CREAR: 'movimientos_recarga.crear',
  MOVIMIENTOS_RECARGA_EDITAR: 'movimientos_recarga.editar',
  MOVIMIENTOS_RECARGA_ELIMINAR: 'movimientos_recarga.eliminar',

  PRESTAMOS_BALON_LISTAR: 'prestamos_balon.listar',
  PRESTAMOS_BALON_VER: 'prestamos_balon.ver',
  PRESTAMOS_BALON_CREAR: 'prestamos_balon.crear',
  PRESTAMOS_BALON_EDITAR: 'prestamos_balon.editar',
  PRESTAMOS_BALON_ELIMINAR: 'prestamos_balon.eliminar',

  PRESTAMOS_DETALLE_LISTAR: 'prestamos_detalle.listar',
  PRESTAMOS_DETALLE_VER: 'prestamos_detalle.ver',
  PRESTAMOS_DETALLE_CREAR: 'prestamos_detalle.crear',
  PRESTAMOS_DETALLE_EDITAR: 'prestamos_detalle.editar',
  PRESTAMOS_DETALLE_ELIMINAR: 'prestamos_detalle.eliminar',

  ALQUILERES_BALON_LISTAR: 'alquileres_balon.listar',
  ALQUILERES_BALON_VER: 'alquileres_balon.ver',
  ALQUILERES_BALON_CREAR: 'alquileres_balon.crear',
  ALQUILERES_BALON_EDITAR: 'alquileres_balon.editar',
  ALQUILERES_BALON_ELIMINAR: 'alquileres_balon.eliminar',

  ALQUILERES_DETALLE_LISTAR: 'alquileres_detalle.listar',
  ALQUILERES_DETALLE_VER: 'alquileres_detalle.ver',
  ALQUILERES_DETALLE_CREAR: 'alquileres_detalle.crear',
  ALQUILERES_DETALLE_EDITAR: 'alquileres_detalle.editar',
  ALQUILERES_DETALLE_ELIMINAR: 'alquileres_detalle.eliminar',

  MANTENIMIENTOS_BALON_LISTAR: 'mantenimientos_balon.listar',
  MANTENIMIENTOS_BALON_VER: 'mantenimientos_balon.ver',
  MANTENIMIENTOS_BALON_CREAR: 'mantenimientos_balon.crear',
  MANTENIMIENTOS_BALON_EDITAR: 'mantenimientos_balon.editar',
  MANTENIMIENTOS_BALON_ELIMINAR: 'mantenimientos_balon.eliminar',

  VENTAS_VER: 'ventas.ver',

  COMPROBANTES_LISTAR: 'comprobantes.listar',
  COMPROBANTES_VER: 'comprobantes.ver',
  COMPROBANTES_CREAR: 'comprobantes.crear',
  COMPROBANTES_EDITAR: 'comprobantes.editar',
  COMPROBANTES_ELIMINAR: 'comprobantes.eliminar',
  COMPROBANTES_EMITIR: 'comprobantes.emitir',
  COMPROBANTES_CONSULTAR_CDR: 'comprobantes.consultar_cdr',

  GUIAS_REMISION_LISTAR: 'guias_remision.listar',
  GUIAS_REMISION_VER: 'guias_remision.ver',
  GUIAS_REMISION_CREAR: 'guias_remision.crear',
  GUIAS_REMISION_EDITAR: 'guias_remision.editar',
  GUIAS_REMISION_ELIMINAR: 'guias_remision.eliminar',
  GUIAS_REMISION_EMITIR: 'guias_remision.emitir',

  CUENTAS_BANCARIAS_LISTAR: 'cuentas_bancarias.listar',
  CUENTAS_BANCARIAS_VER: 'cuentas_bancarias.ver',
  CUENTAS_BANCARIAS_CREAR: 'cuentas_bancarias.crear',
  CUENTAS_BANCARIAS_EDITAR: 'cuentas_bancarias.editar',
  CUENTAS_BANCARIAS_ELIMINAR: 'cuentas_bancarias.eliminar',

  DOCUMENTOS_VENCIMIENTO_LISTAR: 'documentos_vencimiento.listar',
  DOCUMENTOS_VENCIMIENTO_VER: 'documentos_vencimiento.ver',
  DOCUMENTOS_VENCIMIENTO_CREAR: 'documentos_vencimiento.crear',
  DOCUMENTOS_VENCIMIENTO_EDITAR: 'documentos_vencimiento.editar',
  DOCUMENTOS_VENCIMIENTO_ELIMINAR: 'documentos_vencimiento.eliminar',

  BAJAS_CLIENTE_LISTAR: 'bajas_cliente.listar',
  BAJAS_CLIENTE_VER: 'bajas_cliente.ver',
  BAJAS_CLIENTE_SOLICITAR: 'bajas_cliente.solicitar',
  BAJAS_CLIENTE_APROBAR: 'bajas_cliente.aprobar',
  BAJAS_CLIENTE_RECHAZAR: 'bajas_cliente.rechazar',
  BAJAS_CLIENTE_ELIMINAR: 'bajas_cliente.eliminar',
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] =
  Object.values(PermisoBanderas);
