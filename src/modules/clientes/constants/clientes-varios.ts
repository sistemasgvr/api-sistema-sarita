/** Cliente genérico de mostrador (seed codigo_interno = CVARIOS). */
export const CLIENTES_VARIOS_CODIGO = 'CVARIOS';

export function esClientesVarios(cliente: {
  codigo_interno?: string | null;
} | null | undefined): boolean {
  return (cliente?.codigo_interno ?? '').trim().toUpperCase() === CLIENTES_VARIOS_CODIGO;
}
