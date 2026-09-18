import { Injectable } from '@nestjs/common';
import {
  crearEtiquetaDoc,
  ETIQUETA_ALTO_PT,
  ETIQUETA_ANCHO_PT,
  ETIQUETA_ANCHO_UTIL_PT,
  ETIQUETA_MARGEN_PT,
  MM,
} from '../../../common/helpers/etiqueta-pdf.helper';

export interface ProductoUbicacionLabelItem {
  codigo_ubicacion: string;
  codigo: string;
  nombre: string;
}

/**
 * Tarjetas de ubicación en el mismo papel de 50 × 25 mm que el resto de
 * etiquetas: una por página, sin marco de recorte. El código de ubicación es lo
 * que se busca en el anaquel, así que va grande y centrado.
 */
@Injectable()
export class ProductoUbicacionPdfGenerator {
  generarTarjetas(items: ProductoUbicacionLabelItem[]): Promise<Buffer> {
    const { doc, terminado } = crearEtiquetaDoc(
      'Tarjetas de ubicación de productos',
    );
    const x0 = ETIQUETA_MARGEN_PT;
    const ancho = ETIQUETA_ANCHO_UTIL_PT;

    items.forEach((item, index) => {
      if (index > 0)
        doc.addPage({ size: [ETIQUETA_ANCHO_PT, ETIQUETA_ALTO_PT], margin: 0 });
      let y = ETIQUETA_MARGEN_PT;

      doc
        .fillColor('#6b6b6b')
        .font('Helvetica')
        .fontSize(5.5)
        .text('UBICACIÓN', x0, y, {
          width: ancho,
          align: 'center',
          lineBreak: false,
        });
      y += 2.6 * MM;

      doc
        .fillColor('#141414')
        .font('Helvetica-Bold')
        .fontSize(17)
        .text(item.codigo_ubicacion.trim(), x0, y, {
          width: ancho,
          align: 'center',
          lineBreak: false,
          ellipsis: true,
        });
      y += 7.4 * MM;

      doc
        .fillColor('#1e1e1e')
        .font('Helvetica-Bold')
        .fontSize(6.5)
        .text(item.nombre.trim(), x0, y, {
          width: ancho,
          align: 'center',
          height: 2 * 2.6 * MM,
          lineGap: -0.5,
          ellipsis: true,
        });
      y += 2 * 2.6 * MM + 1.2 * MM;

      doc
        .fillColor('#5a5a5a')
        .font('Helvetica')
        .fontSize(6)
        .text(`Cód.: ${item.codigo.trim()}`, x0, y, {
          width: ancho,
          align: 'center',
          lineBreak: false,
          ellipsis: true,
        });
    });

    doc.end();
    return terminado;
  }
}
