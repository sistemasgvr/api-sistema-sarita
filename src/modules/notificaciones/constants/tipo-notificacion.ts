/** Códigos de tipo de notificación (extensibles por escenario). */
export const TipoNotificacion = {
  ALQUILER_VENCIDO: 'ALQUILER_VENCIDO',
  ALQUILER_POR_VENCER: 'ALQUILER_POR_VENCER',
  SISTEMA: 'SISTEMA',
  USUARIO: 'USUARIO',
} as const;

export type TipoNotificacionCodigo =
  (typeof TipoNotificacion)[keyof typeof TipoNotificacion];

export const TipoReferenciaNotificacion = {
  ALQUILER: 'ALQUILER',
  COMPROBANTE: 'COMPROBANTE',
  USUARIO: 'USUARIO',
  SISTEMA: 'SISTEMA',
} as const;
