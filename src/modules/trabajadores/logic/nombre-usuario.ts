export function sugerirNombreUsuario(nombres: string, apellido?: string | null): string {
  const limpiar = (texto: string) => texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
  const nombre = limpiar(nombres.trim().split(/\s+/)[0] ?? '');
  const paterno = limpiar(apellido ?? '');
  return (paterno ? `${nombre.charAt(0)}${paterno}` : nombre) || 'usuario';
}
