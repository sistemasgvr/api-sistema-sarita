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
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] =
  Object.values(PermisoBanderas);
