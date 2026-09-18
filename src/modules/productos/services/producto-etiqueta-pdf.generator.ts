import { Injectable } from '@nestjs/common';
import {
  codigoBarrasPng,
  crearEtiquetaDoc,
  dibujarCabeceraEtiqueta,
  escribirDato,
  ETIQUETA_ANCHO_UTIL_PT,
  ETIQUETA_FILA_DATOS_PT,
  ETIQUETA_MARGEN_PT,
  MM,
} from '../../../common/helpers/etiqueta-pdf.helper';

export interface ProductoEtiquetaDatos {
  codigo: string;
  nombre: string;
  codigo_barra?: string | null;
  nombre_categoria?: string | null;
  nombre_sub_categoria?: string | null;
}

/**
 * Etiqueta 50 × 25 mm del producto: logo, código de barras y debajo nombre,
 * categoría/subcategoría y código. Las barras llevan el `codigo_barra` del
 * producto (el que lee el POS); si no tiene, el código interno.
 */
@Injectable()
export class ProductoEtiquetaPdfGenerator {
  async generar(producto: ProductoEtiquetaDatos): Promise<Buffer> {
    const codigo = producto.codigo.trim();
    const valorBarras = producto.codigo_barra?.trim() || codigo;
    const barras = await codigoBarrasPng(valorBarras);
    const { doc, terminado } = crearEtiquetaDoc(`Etiqueta ${codigo}`);

    const x0 = ETIQUETA_MARGEN_PT;
    const ancho = ETIQUETA_ANCHO_UTIL_PT;
    let y = dibujarCabeceraEtiqueta(doc, barras, valorBarras);

    // El nombre es lo que se lee de lejos: negrita y hasta dos líneas.
    doc
      .font('Helvetica-Bold')
      .fontSize(6.5)
      .text(producto.nombre.trim() || '—', x0, y, {
        width: ancho,
        height: 2 * 2.6 * MM,
        lineGap: -0.5,
        ellipsis: true,
      });
    y += 2 * 2.6 * MM + 0.4 * MM;

    const categoria = [producto.nombre_categoria, producto.nombre_sub_categoria]
      .map((v) => v?.trim())
      .filter(Boolean)
      .join(' / ');
    escribirDato(doc, 'Cat.:', categoria || '—', x0, y, ancho, 5.5 * MM);
    y += ETIQUETA_FILA_DATOS_PT;
    escribirDato(doc, 'Cód.:', codigo || '—', x0, y, ancho, 5.5 * MM);

    doc.end();
    return terminado;
  }
}
