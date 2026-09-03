import { Injectable } from '@nestjs/common';
import PDFDocument from 'pdfkit';
import type { DocumentoSalidaCompletoResult } from '../interfaces/documento-salida.interface';

interface EmpresaEmisora {
  ruc: string;
  razon_social?: string | null;
  nombre_comercial?: string | null;
  direccion?: string | null;
}
@Injectable()
export class DocSalidaPdfGenerator {
  async generarA4(doc: DocumentoSalidaCompletoResult, empresa: EmpresaEmisora): Promise<Buffer> {
    const cabecera = doc.registro;
    if (!cabecera) {
      throw new Error('Documento de salida inválido');
    }

    const detalles = cabecera.detalle ?? [];
    const esGre = Boolean(cabecera.serie && cabecera.numero_sunat);
    const tituloDoc = esGre ? 'GUÍA DE REMISIÓN' : 'ORDEN DE SALIDA';
    const serieNumero = esGre ? `${cabecera.serie}-${cabecera.numero_sunat}` : cabecera.numero;
    const empresaNombre = empresa.razon_social?.trim() || empresa.nombre_comercial?.trim() || 'EMPRESA';

    return new Promise((resolve, reject) => {
      const pdf = new PDFDocument({
        size: 'A4',
        margin: 40,
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

      pdf.font('Helvetica-Bold').fontSize(11).text(empresaNombre, left, y, { width: pageWidth * 0.55 });
      pdf
        .font('Helvetica')
        .fontSize(9)
        .text(`RUC: ${empresa.ruc}`, left, y + 16, { width: pageWidth * 0.55 });
      if (empresa.direccion?.trim()) {
        pdf.text(empresa.direccion.trim(), left, y + 30, { width: pageWidth * 0.55 });
      }

      const boxX = right - 170;
      pdf.roundedRect(boxX, y, 170, 58, 4).stroke('#333333');
      pdf.font('Helvetica-Bold').fontSize(10).text(tituloDoc, boxX, y + 8, { width: 170, align: 'center' });
      pdf
        .font('Helvetica')
        .fontSize(8)
        .text(cabecera.nombre_tipo_orden?.replace(/_/g, ' ') ?? '—', boxX, y + 24, {
          width: 170,
          align: 'center',
        });
      pdf.font('Helvetica-Bold').fontSize(12).text(serieNumero ?? '—', boxX, y + 38, {
        width: 170,
        align: 'center',
      });

      y += 78;

      const motivo = cabecera.nombre_motivo_traslado?.replace(/_/g, ' ') ?? cabecera.codigo_motivo_traslado ?? '—';
      const modalidad =
        cabecera.nombre_modalidad_traslado?.replace(/_/g, ' ') ?? cabecera.codigo_modalidad_traslado ?? '—';

      y = this.kv(pdf, left, y, pageWidth, [
        ['Fecha emisión', cabecera.fecha?.slice(0, 10) ?? '—'],
        ['Fecha traslado', cabecera.fecha_traslado?.slice(0, 10) ?? '—'],
        ['Estado', cabecera.nombre_estado_ciclo ?? '—'],
        ['Motivo', motivo],
        ['Modalidad', modalidad],
        [
          'Peso / bultos',
          `${cabecera.peso_bruto ?? '—'} ${cabecera.nombre_unidad_medida ?? 'kg'} · ${cabecera.numero_bultos ?? '—'} bultos`,
        ],
      ]);

      y += 8;
      const destLabel = cabecera.nombre_proveedor
        ? 'Proveedor'
        : cabecera.nombre_destinatario || cabecera.nombre_cliente
          ? 'Destinatario'
          : 'Almacén destino';
      pdf.font('Helvetica-Bold').fontSize(10).text(destLabel, left, y);
      y += 14;
      pdf
        .font('Helvetica')
        .fontSize(9)
        .text(
          cabecera.nombre_proveedor ?? cabecera.nombre_destinatario ?? cabecera.nombre_cliente ?? cabecera.nombre_almacen ?? '—',
          left,
          y,
          { width: pageWidth },
        );
      y += 13;
      if (cabecera.documento_destinatario) {
        pdf.text(`Doc: ${cabecera.documento_destinatario}`, left, y, { width: pageWidth });
        y += 13;
      }
      y += 5;

      if (esGre) {
        pdf.font('Helvetica-Bold').fontSize(10).text('Traslado', left, y);
        y += 14;
        pdf
          .font('Helvetica')
          .fontSize(9)
          .text(
            `Origen: ${cabecera.direccion_origen ?? '—'} (${cabecera.ubigeo_origen ?? '—'})`,
            left,
            y,
            { width: pageWidth },
          );
        y += 13;
        pdf.text(
          `Destino: ${cabecera.direccion_llegada ?? '—'} (${cabecera.ubigeo_llegada ?? '—'})`,
          left,
          y,
          { width: pageWidth },
        );
        y += 13;

        if (cabecera.codigo_modalidad_traslado === '02') {
          pdf.text(
            `Chofer: ${cabecera.nombre_chofer ?? '—'} · Doc ${cabecera.documento_chofer ?? '—'} · Lic ${cabecera.licencia_chofer ?? '—'}`,
            left,
            y,
            { width: pageWidth },
          );
          y += 13;
          pdf.text(`Vehículo: ${cabecera.placa_vehiculo ?? '—'}`, left, y, { width: pageWidth });
          y += 13;
        } else {
          pdf.text(
            `Transportista: ${cabecera.nombre_transportista ?? '—'} · ${cabecera.documento_transportista ?? ''}`,
            left,
            y,
            { width: pageWidth },
          );
          y += 13;
        }
      }

      if (cabecera.observaciones?.trim()) {
        y += 4;
        pdf
          .font('Helvetica')
          .fontSize(9)
          .text(`Obs.: ${cabecera.observaciones.trim()}`, left, y, { width: pageWidth });
        y += 16;
      }

      y += 8;
      const cols = {
        item: 28,
        cant: 48,
        und: 48,
        codigo: 78,
        desc: pageWidth - 28 - 48 - 48 - 78,
      };
      const xs = {
        item: left,
        cant: left + cols.item,
        und: left + cols.item + cols.cant,
        codigo: left + cols.item + cols.cant + cols.und,
        desc: left + cols.item + cols.cant + cols.und + cols.codigo,
      };

      pdf.rect(left, y, pageWidth, 18).fill('#F3F4F6');
      pdf.fillColor('#111827').font('Helvetica-Bold').fontSize(8);
      pdf.text('#', xs.item + 4, y + 5, { width: cols.item - 6 });
      pdf.text('Cant.', xs.cant + 2, y + 5, { width: cols.cant - 4 });
      pdf.text('Und.', xs.und + 2, y + 5, { width: cols.und - 4 });
      pdf.text('Código', xs.codigo + 2, y + 5, { width: cols.codigo - 4 });
      pdf.text('Descripción', xs.desc + 2, y + 5, { width: cols.desc - 4 });
      y += 18;

      pdf.font('Helvetica').fontSize(8).fillColor('#111827');
      for (const detalle of detalles) {
        const desc =
          detalle.glosa?.trim() ||
          detalle.descripcion?.trim() ||
          detalle.nombre_producto ||
          (detalle.id_producto != null ? `Producto ${detalle.id_producto}` : 'Ítem');
        const codigo = detalle.codigo_balon?.trim() || detalle.codigo_producto || '—';
        const rowH = Math.max(16, pdf.heightOfString(desc, { width: cols.desc - 6 }) + 8);

        if (y + rowH > pdf.page.height - pdf.page.margins.bottom - 40) {
          pdf.addPage();
          y = pdf.page.margins.top;
        }

        pdf.text(String(detalle.item ?? ''), xs.item + 4, y + 4, { width: cols.item - 6 });
        pdf.text(String(detalle.cantidad ?? ''), xs.cant + 2, y + 4, { width: cols.cant - 4 });
        pdf.text(detalle.nombre_unidad_medida ?? '—', xs.und + 2, y + 4, { width: cols.und - 4 });
        pdf.text(codigo, xs.codigo + 2, y + 4, { width: cols.codigo - 4 });
        pdf.text(desc, xs.desc + 2, y + 4, { width: cols.desc - 6 });
        y += rowH;
        pdf.moveTo(left, y).lineTo(right, y).strokeColor('#E5E7EB').stroke();
      }

      y += 20;
      pdf
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#6B7280')
        .text(
          esGre
            ? `Estado SUNAT: ${cabecera.nombre_estado_sunat ?? 'PENDIENTE'}${cabecera.hash_documento ? ` · Hash: ${cabecera.hash_documento}` : ''}`
            : `Documento interno — no emitido a SUNAT`,
          left,
          y,
          { width: pageWidth },
        );

      pdf.end();
    });
  }

  private kv(
    pdf: InstanceType<typeof PDFDocument>,
    left: number,
    y: number,
    pageWidth: number,
    rows: [string, string][],
  ) {
    const colW = pageWidth / 2;
    let rowY = y;
    for (let i = 0; i < rows.length; i += 2) {
      const leftRow = rows[i];
      const rightRow = rows[i + 1];
      pdf.font('Helvetica').fontSize(8).fillColor('#6B7280');
      pdf.text(leftRow[0], left, rowY, { width: colW - 8 });
      if (rightRow) {
        pdf.text(rightRow[0], left + colW, rowY, { width: colW - 8 });
      }
      pdf.font('Helvetica').fontSize(9).fillColor('#111827');
      pdf.text(leftRow[1], left, rowY + 11, { width: colW - 8 });
      if (rightRow) {
        pdf.text(rightRow[1], left + colW, rowY + 11, { width: colW - 8 });
      }
      rowY += 28;
    }
    return rowY;
  }
}
