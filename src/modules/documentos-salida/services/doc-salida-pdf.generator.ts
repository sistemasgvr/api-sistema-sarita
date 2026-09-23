import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import PDFDocument from 'pdfkit';
import sharp from 'sharp';
import type { DocumentoSalidaCompletoResult } from '../interfaces/documento-salida.interface';

/**
 * El logo vive en src/assets y nest-cli lo copia a dist al compilar, por eso se
 * busca en las dos rutas. pdfkit solo acepta PNG y JPEG, así que el .webp se
 * convierte con sharp una única vez y se guarda en memoria.
 */
const LOGO_WEBP = 'logo-sarita.webp';
const LOGO_ANCHO_PT = 110;

interface EmpresaEmisora {
  ruc: string;
  razon_social?: string | null;
  nombre_comercial?: string | null;
  direccion?: string | null;
}
@Injectable()
export class DocSalidaPdfGenerator {
  private readonly logger = new Logger(DocSalidaPdfGenerator.name);
  private logoCache?: { buffer: Buffer; alto: number } | null;

  /** Devuelve el logo listo para pdfkit, o null si no está disponible. */
  private async cargarLogo(): Promise<{ buffer: Buffer; alto: number } | null> {
    if (this.logoCache !== undefined) return this.logoCache;

    const rutas = [
      join(__dirname, '..', '..', '..', 'assets', LOGO_WEBP),
      join(process.cwd(), 'src', 'assets', LOGO_WEBP),
      join(process.cwd(), 'dist', 'assets', LOGO_WEBP),
    ];
    const ruta = rutas.find((candidata) => existsSync(candidata));

    if (!ruta) {
      // Sin logo el documento sigue siendo válido: se registra y se continúa.
      this.logger.warn(`No se encontró ${LOGO_WEBP}; el PDF saldrá sin logo`);
      this.logoCache = null;
      return null;
    }

    try {
      const original = sharp(readFileSync(ruta));
      const { width, height } = await original.metadata();
      const buffer = await original.png().toBuffer();
      const alto =
        width && height
          ? Math.round((LOGO_ANCHO_PT * height) / width)
          : LOGO_ANCHO_PT;
      this.logoCache = { buffer, alto };
    } catch (error) {
      this.logger.warn(
        `No se pudo convertir ${LOGO_WEBP} a PNG: ${(error as Error).message}`,
      );
      this.logoCache = null;
    }

    return this.logoCache;
  }

  /**
   * `empresa` llega en null cuando la orden interna todavía no tiene emisor
   * configurado: el PDF sale sin membrete en vez de no salir.
   */
  async generarA4(
    doc: DocumentoSalidaCompletoResult,
    empresa: EmpresaEmisora | null,
  ): Promise<Buffer> {
    const cabecera = doc.registro;
    if (!cabecera) {
      throw new Error('Documento de salida inválido');
    }

    const faltantes: string[] = [];
    if (!cabecera.id_tipo_guia_remision) faltantes.push('tipo de guía');
    if (!cabecera.id_motivo_traslado) faltantes.push('motivo');
    if (!cabecera.id_modalidad_traslado) faltantes.push('modalidad');
    if (!cabecera.fecha_traslado) faltantes.push('fecha de traslado');
    if (!(Number(cabecera.peso_bruto) > 0)) faltantes.push('peso bruto mayor a cero');
    if (!(Number(cabecera.numero_bultos) > 0) || !Number.isInteger(Number(cabecera.numero_bultos))) faltantes.push('bultos enteros mayores a cero');
    if (cabecera.codigo_modalidad_traslado === '02' || cabecera.codigo_tipo_guia === '31') {
      if (!cabecera.id_chofer) faltantes.push('chofer');
      if (!cabecera.id_vehiculo) faltantes.push('vehículo');
    } else if (!cabecera.id_transportista) faltantes.push('transportista');
    if (faltantes.length) throw new BadRequestException(`Completa y guarda los datos de traslado antes de generar el PDF: ${faltantes.join(', ')}.`);

    const detalles = cabecera.detalle ?? [];
    const esGre = Boolean(cabecera.serie && cabecera.numero_sunat);
    const tituloDoc = esGre ? 'GUÍA DE REMISIÓN' : 'ORDEN DE SALIDA';
    const serieNumero = esGre
      ? `${cabecera.serie}-${cabecera.numero_sunat}`
      : cabecera.numero;
    const empresaNombre =
      empresa?.razon_social?.trim() ||
      empresa?.nombre_comercial?.trim() ||
      'EMPRESA';
    const logo = await this.cargarLogo();

    return new Promise((resolve, reject) => {
      const pdf = new PDFDocument({
        size: 'A4',
        margin: 40,
        bufferPages: true,
        info: { Title: `${tituloDoc} ${serieNumero}`, Author: empresaNombre },
      });

      const chunks: Buffer[] = [];
      pdf.on('data', (chunk: Buffer) => chunks.push(chunk));
      pdf.on('end', () => resolve(Buffer.concat(chunks)));
      pdf.on('error', reject);

      const left = pdf.page.margins.left;
      const right = pdf.page.width - pdf.page.margins.right;
      const pageWidth = right - left;
      let y = pdf.page.margins.top;

      const ink = '#1e293b';
      const muted = '#64748b';
      const border = '#cbd5e1';
      const bottom = pdf.page.height - 76;
      const text = (value: string, x: number, top: number, width: number, size = 9, bold = false, color = ink) => {
        pdf.font(bold ? 'Helvetica-Bold' : 'Helvetica').fontSize(size).fillColor(color).text(value, x, top, { width });
        return pdf.y;
      };
      const line = (x: number, top: number, width: number) => pdf.moveTo(x, top).lineTo(x + width, top).lineWidth(0.6).strokeColor(border).stroke();
      const ensure = (height: number) => {
        if (y + height > bottom) { pdf.addPage(); y = 40; }
      };
      const headerWidth = pageWidth - 206;
      if (logo) pdf.image(logo.buffer, left, y, { width: 94 });
      text('GASES MEDICINALES\nE INDUSTRIALES', left + 106, y + 12, headerWidth - 110, 9, true, muted);
      const companyY = y + Math.max(68, logo ? logo.alto * 94 / LOGO_ANCHO_PT + 8 : 68);
      const companyEnd = text(empresaNombre, left, companyY, headerWidth, 11, true);
      const addressEnd = text([empresa?.ruc ? `RUC: ${empresa.ruc}` : '', empresa?.direccion].filter(Boolean).join(' · '), left, companyEnd + 5, headerWidth, 8, false, muted);
      const bx = right - 190;
      pdf.roundedRect(bx, y, 190, 96, 5).lineWidth(1.3).strokeColor(ink).stroke();
      text(empresa?.ruc ? `R.U.C. ${empresa.ruc}` : empresaNombre, bx + 12, y + 12, 166, 10, true);
      line(bx + 12, y + 31, 166);
      text(tituloDoc, bx + 12, y + 42, 166, 12, true);
      line(bx + 12, y + 62, 166);
      text(serieNumero ?? '—', bx + 12, y + 73, 166, 11, true);
      y = Math.max(addressEnd + 18, y + 114);
      line(left, y, pageWidth);
      y += 16;

      const metadata: [string, string][] = [
        ['FECHA EMISIÓN', (esGre ? cabecera.fecha_emision_gre : cabecera.fecha)?.slice(0, 10) ?? '—'],
        ['FECHA TRASLADO', cabecera.fecha_traslado?.slice(0, 10) ?? '—'],
        ['ESTADO', cabecera.nombre_estado_ciclo ?? '—'],
        ['MOTIVO TRASLADO', cabecera.nombre_motivo_traslado?.replace(/_/g, ' ') ?? cabecera.codigo_motivo_traslado ?? '—'],
        ['MODALIDAD', cabecera.nombre_modalidad_traslado?.replace(/_/g, ' ') ?? '—'],
        ['N° DE BULTOS', String(cabecera.numero_bultos)],
        ['PESO BRUTO TOTAL', `${cabecera.peso_bruto} ${cabecera.nombre_unidad_medida ?? 'kg'}`],
        ['TIPO DE GUÍA', cabecera.codigo_tipo_guia === '31' ? 'Transportista (31)' : 'Remitente (09)'],
      ];
      const cardWidth = (pageWidth - 24) / 4;
      for (let offset = 0; offset < metadata.length; offset += 4) {
        pdf.font('Helvetica-Bold').fontSize(9);
        const height = Math.max(47, ...metadata.slice(offset, offset + 4).map(([, value]) => pdf.heightOfString(value, { width: cardWidth - 16 }) + 28));
        metadata.slice(offset, offset + 4).forEach(([label, value], i) => {
          const x = left + i * (cardWidth + 8);
          pdf.roundedRect(x, y, cardWidth, height, 4).lineWidth(0.6).strokeColor(border).stroke();
          text(label, x + 8, y + 8, cardWidth - 16, 7, true, muted);
          text(value, x + 8, y + 23, cardWidth - 16, 9, true);
        });
        y += height + 8;
      }
      y += 8;
      const esPlanta = cabecera.nombre_tipo_orden === 'RECARGA_PLANTA_EXTERNA';
      const destinatario = (esPlanta ? cabecera.nombre_proveedor : cabecera.nombre_destinatario ?? cabecera.nombre_cliente ?? cabecera.nombre_proveedor) ?? cabecera.nombre_almacen_destino ?? cabecera.nombre_almacen ?? '—';
      const documentoDestino = esPlanta ? cabecera.documento_proveedor : cabecera.documento_destinatario ?? cabecera.documento_cliente;
      const destino = cabecera.direccion_llegada ?? cabecera.direccion_entrega ?? cabecera.direccion_almacen_destino ?? '—';
      const ubigeo = cabecera.ubigeo_llegada ?? cabecera.ubigeo_entrega;
      const colW = (pageWidth - 48) / 2;
      const recipient = [destinatario, documentoDestino ? `Documento: ${documentoDestino}` : '', `Punto de llegada: ${destino}`, ubigeo ? `Ubigeo: ${ubigeo}` : '', cabecera.referencia_entrega ? `Referencia: ${cabecera.referencia_entrega}` : ''].filter(Boolean);
      const transport = [
        `Origen: ${cabecera.direccion_origen ?? cabecera.direccion_almacen ?? '—'}${cabecera.ubigeo_origen ? ` (${cabecera.ubigeo_origen})` : ''}`,
        ...(cabecera.codigo_modalidad_traslado === '02' || cabecera.codigo_tipo_guia === '31'
          ? [`Chofer: ${cabecera.nombre_chofer ?? '—'}`, `Doc: ${cabecera.documento_chofer ?? '—'} · Lic: ${cabecera.licencia_chofer ?? '—'}`, `Vehículo: ${cabecera.placa_vehiculo ?? cabecera.placa ?? '—'}`]
          : [`Transportista: ${cabecera.nombre_transportista ?? '—'}`, `Documento: ${cabecera.documento_transportista ?? '—'}`]),
      ];
      pdf.font('Helvetica').fontSize(9);
      const measure = (rows: string[]) => rows.reduce((h, row) => h + pdf.heightOfString(row, { width: colW }) + 6, 0);
      const infoHeight = Math.max(measure(recipient), measure(transport)) + 40;
      ensure(infoHeight);
      pdf.roundedRect(left, y, pageWidth, infoHeight, 5).lineWidth(0.6).strokeColor(border).stroke();
      const drawInfo = (title: string, rows: string[], x: number) => {
        text(title, x, y + 12, colW, 8, true);
        let top = y + 32;
        for (const row of rows) top = text(row, x, top, colW) + 6;
      };
      drawInfo('DESTINATARIO Y ENTREGA', recipient, left + 12);
      drawInfo('TRASLADO Y TRANSPORTE', transport, left + pageWidth / 2 + 12);
      pdf.moveTo(left + pageWidth / 2, y + 12).lineTo(left + pageWidth / 2, y + infoHeight - 12).strokeColor(border).stroke();
      y += infoHeight + 18;
      if (cabecera.observaciones?.trim()) {
        pdf.font('Helvetica').fontSize(9);
        ensure(pdf.heightOfString(cabecera.observaciones, { width: pageWidth }) + 25);
        y = text(`Observaciones: ${cabecera.observaciones.trim()}`, left, y, pageWidth) + 14;
      }
      const tabla = (title: string, headers: string[], widths: number[], rows: string[][]) => {
        if (!rows.length) return;
        const header = () => {
          text(title, left, y, pageWidth, 10, true);
          y += 20;
          pdf.rect(left, y, pageWidth, 26).fill('#f1f5f9');
          let x = left;
          headers.forEach((label, i) => {
            pdf.rect(x, y, widths[i], 26).lineWidth(0.5).strokeColor(border).stroke();
            text(label, x + 7, y + 9, widths[i] - 14, 7, true);
            x += widths[i];
          });
          y += 26;
        };
        ensure(80);
        header();
        for (const row of rows) {
          pdf.font('Helvetica').fontSize(9);
          const height = Math.max(28, ...row.map((value, i) => pdf.heightOfString(value, { width: widths[i] - 14 }) + 14));
          if (y + height > bottom) { pdf.addPage(); y = 40; header(); }
          let x = left;
          row.forEach((value, i) => {
            pdf.rect(x, y, widths[i], height).lineWidth(0.5).strokeColor(border).stroke();
            text(value, x + 7, y + 7, widths[i] - 14);
            x += widths[i];
          });
          y += height;
        }
        y += 20;
      };
      const cilindros = [...new Map(detalles.filter(d => d.id_balon != null).map(d => [d.id_balon, d])).values()];
      tabla(`Cilindros (${cilindros.length})`, ['#', 'CÓDIGO BALÓN', 'TIPO DE CILINDRO / CAPACIDAD', 'CANTIDAD'], [28, 118, pageWidth - 212, 66],
        cilindros.map((d, i) => [String(i + 1), d.codigo_balon ?? '—', d.nombre_tipo_balon ?? 'Cilindro', '1']));
      const productos = detalles.filter(d => (d.id_balon == null || d.id_producto != null || (d.id_producto_gas_balon != null && d.origen_detalle === 'VENTA')) && d.origen_detalle !== 'PRESTAMO');
      tabla('Productos / gas despachado', ['#', 'CÓDIGO', 'DESCRIPCIÓN DEL PRODUCTO', 'CANTIDAD', 'UNIDAD'], [28, 88, pageWidth - 244, 66, 62],
        productos.map((d, i) => [String(i + 1), d.codigo_producto?.trim() || d.codigo_producto_gas_balon?.trim() || 'S/C', d.glosa?.trim() || d.descripcion?.trim() || d.nombre_producto || d.nombre_producto_gas_balon || 'Producto', String(d.cantidad), d.nombre_unidad_medida ?? d.codigo_unidad_medida ?? d.unidad_capacidad_balon ?? '—']));
      ensure(98);
      y = Math.max(y + 60, bottom - 40);
      const signatureWidth = 192;
      [left + 12, right - signatureWidth - 12].forEach(x => line(x, y, signatureWidth));
      text('FIRMA / SELLO DESPACHO', left + 12, y + 9, signatureWidth, 8, true);
      text(empresaNombre, left + 12, y + 23, signatureWidth, 7, false, muted);
      text('FIRMA / DNI RECEPCIÓN', right - signatureWidth - 12, y + 9, signatureWidth, 8, true);
      text('Conformidad del cliente', right - signatureWidth - 12, y + 23, signatureWidth, 7, false, muted);
      const pageCount = pdf.bufferedPageRange().count;
      const printedAt = new Intl.DateTimeFormat('sv-SE', { timeZone: 'America/Lima', dateStyle: 'short', timeStyle: 'short' }).format(new Date());
      for (let page = 0; page < pageCount; page++) {
        pdf.switchToPage(page);
        pdf.page.margins.bottom = 20;
        const footerY = pdf.page.height - 51;
        line(left, footerY, pageWidth);
        const note = esGre ? `Estado SUNAT: ${cabecera.nombre_estado_sunat ?? 'PENDIENTE'}${cabecera.gre_entorno ? ` · ${cabecera.gre_entorno}` : ''}` : 'Documento de control interno - No emitido a SUNAT';
        text(note, left, footerY + 8, pageWidth, 7, false, muted);
        text(`Impresión: ${printedAt}   ·   Pág. ${page + 1} de ${pageCount}`, left, footerY + 20, pageWidth, 7, false, muted);
      }

      pdf.end();
    });
  }

}
