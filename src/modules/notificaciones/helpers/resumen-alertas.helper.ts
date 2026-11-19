/**
 * Textos de las alertas diarias que se envían como **un resumen por día** y no
 * como una notificación por registro. La alerta de P.H. mandaba una por
 * cilindro, todos los días, a cada usuario: con muchos cilindros se volvía
 * ruido y se ignoraba (docs/RESPUESTA-REVISION-PREVENTIVA.md §6).
 */

export interface ResumenAlerta {
  titulo: string;
  mensaje: string;
}

export interface PhRow {
  id: number;
  codigo_balon?: string | null;
  fecha_proxima?: string | null;
  dias_restantes?: number | null;
}

export interface CuentaAlertaRow {
  id: number;
  tercero?: string | null;
  numero_comprobante?: string | null;
  fecha_vencimiento?: string | null;
  /** COBRAR: días vencida (> 0). PAGAR: negativo = días que faltan. */
  dias?: number | null;
  saldo?: number | string | null;
}

export interface GarantiaAlertaRow {
  id: number;
  nombre_cliente?: string | null;
  fecha_devolucion?: string | null;
  dias?: number | null;
  saldo?: number | string | null;
}

const soles = new Intl.NumberFormat('es-PE', {
  style: 'currency',
  currency: 'PEN',
});

export function formatearSoles(monto: number): string {
  return soles.format(Number.isFinite(monto) ? monto : 0);
}

const plural = (n: number, singular: string, pluralTxt: string) =>
  `${n} ${n === 1 ? singular : pluralTxt}`;

const sumaSaldos = (rows: Array<{ saldo?: number | string | null }>) =>
  rows.reduce((acc, r) => acc + (Number(r.saldo) || 0), 0);

const fecha = (valor?: string | null) => String(valor ?? '').slice(0, 10);

export function resumenPh(rows: PhRow[], dias: number): ResumenAlerta | null {
  if (rows.length === 0) return null;
  const [primero] = [...rows].sort(
    (a, b) => Number(a.dias_restantes ?? 0) - Number(b.dias_restantes ?? 0),
  );
  const codigo = primero.codigo_balon?.trim() || `Cilindro #${primero.id}`;
  const restantes = Number(primero.dias_restantes ?? 0);
  const cuando =
    restantes < 0
      ? `vencida hace ${Math.abs(restantes)} día(s)`
      : `en ${restantes} día(s)`;
  return {
    titulo: 'P.H. de cilindros por vencer',
    mensaje:
      `${plural(rows.length, 'cilindro tiene', 'cilindros tienen')} la prueba hidrostática por vencer en los próximos ${dias} días. ` +
      `El más próximo: ${codigo}, ${cuando} (${fecha(primero.fecha_proxima)}). Revisa Balones → Cilindros.`,
  };
}

export function resumenCxcVencidas(
  rows: CuentaAlertaRow[],
): ResumenAlerta | null {
  if (rows.length === 0) return null;
  const masAntigua = rows.reduce((a, b) =>
    Number(b.dias ?? 0) > Number(a.dias ?? 0) ? b : a,
  );
  const clientes = new Set(rows.map((r) => r.tercero ?? r.id)).size;
  return {
    titulo: 'Cuentas por cobrar vencidas',
    mensaje:
      `${plural(rows.length, 'cuenta por cobrar vencida', 'cuentas por cobrar vencidas')} ` +
      `de ${plural(clientes, 'cliente', 'clientes')}, por ${formatearSoles(sumaSaldos(rows))}. ` +
      `La más antigua: ${masAntigua.tercero ?? 'sin nombre'}, ${Number(masAntigua.dias ?? 0)} día(s) de atraso. ` +
      `Revisa Finanzas → Cuentas por cobrar.`,
  };
}

export function resumenCxpPorVencer(
  rows: CuentaAlertaRow[],
  dias: number,
): ResumenAlerta | null {
  if (rows.length === 0) return null;
  const vencidas = rows.filter((r) => Number(r.dias ?? 0) > 0);
  const proximas = rows.length - vencidas.length;
  const partes: string[] = [];
  if (vencidas.length) {
    partes.push(
      `${plural(vencidas.length, 'cuenta por pagar vencida', 'cuentas por pagar vencidas')} (${formatearSoles(sumaSaldos(vencidas))})`,
    );
  }
  if (proximas) {
    partes.push(
      `${plural(proximas, 'vence', 'vencen')} en los próximos ${dias} días (${formatearSoles(sumaSaldos(rows) - sumaSaldos(vencidas))})`,
    );
  }
  return {
    titulo: vencidas.length
      ? 'Cuentas por pagar vencidas'
      : 'Cuentas por pagar por vencer',
    mensaje: `${partes.join('; ')}. Revisa Finanzas → Cuentas por pagar.`,
  };
}

export function resumenGarantiasPorDevolver(
  rows: GarantiaAlertaRow[],
): ResumenAlerta | null {
  if (rows.length === 0) return null;
  const masAntigua = rows.reduce((a, b) =>
    Number(b.dias ?? 0) > Number(a.dias ?? 0) ? b : a,
  );
  return {
    titulo: 'Garantías sin devolver',
    mensaje:
      `${plural(rows.length, 'garantía sigue', 'garantías siguen')} con saldo aunque el envase ya volvió, ` +
      `por ${formatearSoles(sumaSaldos(rows))}. ` +
      `La más antigua: ${masAntigua.nombre_cliente || 'sin nombre'}, devuelto hace ${Number(masAntigua.dias ?? 0)} día(s). ` +
      `Revisa Finanzas → Garantías.`,
  };
}
