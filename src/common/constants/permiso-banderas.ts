/**
 * Banderas de permiso. El nombre en BD (auth_permisos.nombre) debe coincidir con el valor.
 * auth.todo = acceso total (superadmin).
 */
export const PermisoBanderas = {
  AUTH_TODO: 'auth.todo',

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
} as const;

export type PermisoBandera =
  (typeof PermisoBanderas)[keyof typeof PermisoBanderas];

export const TODAS_LAS_BANDERAS: PermisoBandera[] = Object.values(
  PermisoBanderas,
);
