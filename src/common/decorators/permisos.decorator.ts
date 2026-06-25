import { SetMetadata } from '@nestjs/common';
import type { PermisoBandera } from '../constants/permiso-banderas';

export const PERMISOS_KEY = 'permisos';

/** Exige que el usuario tenga todas las banderas indicadas (o auth.todo). */
export const Permisos = (...permisos: PermisoBandera[]) =>
  SetMetadata(PERMISOS_KEY, permisos);
