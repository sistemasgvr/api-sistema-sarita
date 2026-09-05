import type { ComprobanteDetalleRegistro } from '../interfaces/comprobante.interface';

/**
 * Reconoce las líneas de garantía que el POS cobraba dentro de la venta antes
 * de que la garantía pasara a vivir solo en ven_garantia.
 *
 * `es_linea_garantia` lo resuelve ven_obtener_comprobante con el mismo criterio
 * que ven_producto_mueve_kardex_venta usa para no descontar stock por ellas; la
 * comparación de texto queda como respaldo para cualquier camino que arme el
 * comprobante sin pasar por esa función.
 */
export function esLineaGarantia(detalle: ComprobanteDetalleRegistro): boolean {
  if (detalle.es_linea_garantia === true) return true;
  return /garant[ií]a/i.test(detalle.descripcion ?? '');
}

/** Las líneas que sí son venta: lo único que se declara y lo único que se despacha. */
export function lineasDeVenta(
  detalles: ComprobanteDetalleRegistro[],
): ComprobanteDetalleRegistro[] {
  return detalles.filter((detalle) => !esLineaGarantia(detalle));
}
