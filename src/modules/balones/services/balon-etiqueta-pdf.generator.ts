import { Injectable } from '@nestjs/common';
import {
  codigoBarrasPng,
  crearEtiquetaDoc,
  dibujarCabeceraEtiqueta,
  escribirDato,
  ETIQUETA_ANCHO_UTIL_PT,
  ETIQUETA_FILA_DATOS_PT,
  ETIQUETA_MARGEN_PT,
  formatearFechaEtiqueta,
  MM,
} from '../../../common/helpers/etiqueta-pdf.helper';

export interface BalonEtiquetaDatos {
  codigo_balon: string;
  nombre_tipo_balon?: string | null;
  nombre_producto_gas?: string | null;
  nombre_marca_cilindro?: string | null;
  /** La fabricación se registra a mes/año; la fecha completa es el respaldo. */
  fecha_fabricacion?: string | null;
  anio_fabricacion?: number | null;
  mes_fabricacion?: number | null;
  fecha_proxima_prueba_hidrostatica?: string | null;
}

/**
 * Etiqueta 50 × 25 mm del cilindro: logo, Code 128 del código (lo lee cualquier
 * pistola) y debajo tipo, marca, fabricación y vencimiento de la PH.
 */
@Injectable()
export class BalonEtiquetaPdfGenerator {
  async generar(balon: BalonEtiquetaDatos): Promise<Buffer> {
    const codigo = balon.codigo_balon.trim();
    const barras = await codigoBarrasPng(codigo);
    const { doc, terminado } = crearEtiquetaDoc(`Etiqueta ${codigo}`);

    const x0 = ETIQUETA_MARGEN_PT;
    const ancho = ETIQUETA_ANCHO_UTIL_PT;
    const mitad = ancho / 2;
    let y = dibujarCabeceraEtiqueta(doc, barras, codigo);

    // Tres filas; marca y fabricación comparten una para que quepa todo.
    const tipo =
      balon.nombre_tipo_balon?.trim() ||
      balon.nombre_producto_gas?.trim() ||
      '—';
    escribirDato(doc, 'Tipo:', tipo, x0, y, ancho, 6 * MM);
    y += ETIQUETA_FILA_DATOS_PT;
    escribirDato(
      doc,
      'Marca:',
      balon.nombre_marca_cilindro?.trim() || '—',
      x0,
      y,
      mitad - MM,
      8 * MM,
    );
    escribirDato(
      doc,
      'Fab.:',
      formatearMesAnio(balon),
      x0 + mitad,
      y,
      mitad,
      6 * MM,
    );
    y += ETIQUETA_FILA_DATOS_PT;
    escribirDato(
      doc,
      'PH vence:',
      formatearFechaEtiqueta(balon.fecha_proxima_prueba_hidrostatica),
      x0,
      y,
      ancho,
      11 * MM,
    );

    doc.end();
    return terminado;
  }
}

/** Fabricación a `MM/AAAA`: primero mes/año registrados, si no la fecha completa. */
function formatearMesAnio(balon: BalonEtiquetaDatos): string {
  const { mes_fabricacion: mes, anio_fabricacion: anio } = balon;
  if (mes != null && anio != null && mes >= 1 && mes <= 12) {
    return `${String(mes).padStart(2, '0')}/${anio}`;
  }
  const m = /^(\d{4})-(\d{2})/.exec(balon.fecha_fabricacion ?? '');
  return m ? `${m[2]}/${m[1]}` : '—';
}
