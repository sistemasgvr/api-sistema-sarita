import { ForbiddenException, BadRequestException } from '@nestjs/common';
import { posix } from 'node:path';
import {
  PermisoBanderas,
  type PermisoBandera,
} from '../../../common/constants/permiso-banderas';

/**
 * Permisos de `storage` por carpeta.
 *
 * Antes todo el módulo exigía `configuracion_sunat.*`, porque en el mismo
 * bucket vive el certificado digital SUNAT (`certificados/…`). Eso dejaba sin
 * poder adjuntar a quien registra compras, activos o lotes de protocolo
 * (docs/RESPUESTA-REVISION-PREVENTIVA.md §4).
 *
 * Ahora cada carpeta de negocio pide el permiso de su módulo y **todo lo demás**
 * (incluido `certificados/`) sigue exigiendo Configuración SUNAT. La ruta se
 * normaliza antes de comparar para que `compras/../certificados/x` no pase.
 */

export type ModoAcceso = 'ver' | 'editar';

interface CarpetaNegocio {
  prefijo: string;
  ver: PermisoBandera[];
  editar: PermisoBandera[];
}

export const CARPETAS_NEGOCIO: readonly CarpetaNegocio[] = [
  {
    prefijo: 'compras/',
    ver: [PermisoBanderas.COMPRAS_VER, PermisoBanderas.COMPRAS_LISTAR],
    editar: [PermisoBanderas.COMPRAS_CREAR, PermisoBanderas.COMPRAS_EDITAR],
  },
  {
    prefijo: 'activos/',
    ver: [PermisoBanderas.ACTIVO_VER, PermisoBanderas.ACTIVO_LISTAR],
    editar: [PermisoBanderas.ACTIVO_CREAR, PermisoBanderas.ACTIVO_EDITAR],
  },
  {
    prefijo: 'lotes-protocolo/',
    ver: [
      PermisoBanderas.LOTES_PROTOCOLO_VER,
      PermisoBanderas.LOTES_PROTOCOLO_LISTAR,
    ],
    editar: [
      PermisoBanderas.LOTES_PROTOCOLO_CREAR,
      PermisoBanderas.LOTES_PROTOCOLO_EDITAR,
    ],
  },
];

const PERMISO_RESTO: Record<ModoAcceso, PermisoBandera> = {
  ver: PermisoBanderas.CONFIGURACION_SUNAT_VER,
  editar: PermisoBanderas.CONFIGURACION_SUNAT_EDITAR,
};

/** Normaliza la ruta y rechaza las que salen de la raíz del bucket. */
export function normalizarRutaStorage(ruta: string): string {
  const limpia = posix.normalize(
    String(ruta ?? '')
      .trim()
      .replace(/\\/g, '/'),
  );
  if (
    !limpia ||
    limpia === '.' ||
    limpia.startsWith('/') ||
    limpia === '..' ||
    limpia.startsWith('../')
  ) {
    throw new BadRequestException('Ruta de archivo inválida');
  }
  return limpia;
}

/** Permisos que habilitan (cualquiera de ellos) el acceso a la ruta. */
export function permisosRequeridos(
  ruta: string,
  modo: ModoAcceso,
): PermisoBandera[] {
  const normalizada = normalizarRutaStorage(ruta);
  const carpeta = CARPETAS_NEGOCIO.find((c) =>
    normalizada.startsWith(c.prefijo),
  );
  return carpeta ? carpeta[modo] : [PERMISO_RESTO[modo]];
}

export function puedeAccederRuta(
  permisosUsuario: readonly string[],
  ruta: string,
  modo: ModoAcceso,
): boolean {
  if (permisosUsuario.includes(PermisoBanderas.AUTH_TODO)) return true;
  return permisosRequeridos(ruta, modo).some((p) =>
    permisosUsuario.includes(p),
  );
}

export function exigirAccesoRuta(
  permisosUsuario: readonly string[] | undefined,
  ruta: string,
  modo: ModoAcceso,
): string {
  const normalizada = normalizarRutaStorage(ruta);
  if (!puedeAccederRuta(permisosUsuario ?? [], normalizada, modo)) {
    throw new ForbiddenException(
      modo === 'editar'
        ? 'No tienes permiso para subir o eliminar archivos en esta carpeta.'
        : 'No tienes permiso para ver archivos de esta carpeta.',
    );
  }
  return normalizada;
}
