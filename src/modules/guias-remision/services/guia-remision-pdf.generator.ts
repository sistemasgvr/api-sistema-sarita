import { Injectable } from '@nestjs/common';
import PDFDocument from 'pdfkit';
import type { GuiaRemisionCompletoResult } from '../interfaces/guia-remision.interface';

interface EmpresaEmisora {
  ruc: string;
  razon_social?: string | null;
  nombre_comercial?: string | null;
  direccion?: string | null;
}

/**
 * PDF A4 local para Guía de Remisión (impreso / archivo interno).
 */
@Injectable()
export class GuiaRemisionPdfGenerator {
  async generarA4(
    guia: GuiaRemisionCompletoResult,
    empresa: EmpresaEmisora,
  ): Promise<Buffer> {
    const cabecera = guia.registro;
    if (!cabecera) {
      throw new Error('Guía inválida');
    }

    const detalles = guia.detalles ?? [];
    const serieNumero = `${cabecera.serie}-${cabecera.numero}`;
    const empresaNombre =
      empresa.razon_social?.trim() ||
      empresa.nombre_comercial?.trim() ||
      'EMPRESA';

    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 40,
        info: {
          Title: `Guía de remisión ${serieNumero}`,
          Author: empresaNombre,
        },
      });

      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const left = doc.page.margins.left;
      const right = doc.page.width - doc.page.margins.right;
      const pageWidth = right - left;
      let y = doc.page.margins.top;

      doc
        .font('Helvetica-Bold')
        .fontSize(11)
        .text(empresaNombre, left, y, { width: pageWidth * 0.55 });
      doc
        .font('Helvetica')
        .fontSize(9)
        .text(`RUC: ${empresa.ruc}`, left, y + 16, {
          width: pageWidth * 0.55,
        });
      if (empresa.direccion?.trim()) {
        doc.text(empresa.direccion.trim(), left, y + 30, {
          width: pageWidth * 0.55,
        });
      }

      const boxX = right - 170;
      doc.roundedRect(boxX, y, 170, 58, 4).stroke('#333333');
      doc
        .font('Helvetica-Bold')
        .fontSize(10)
        .text('GUÍA DE REMISIÓN', boxX, y + 8, {
          width: 170,
          align: 'center',
        });
      doc
        .font('Helvetica')
        .fontSize(8)
        .text(
          `Tipo ${(cabecera.codigo_tipo_guia ?? '').trim() || '09'}`,
          boxX,
          y + 24,
          { width: 170, align: 'center' },
        );
      doc
        .font('Helvetica-Bold')
        .fontSize(12)
        .text(serieNumero, boxX, y + 38, { width: 170, align: 'center' });

      y += 78;

      const tipoLabel =
        cabecera.nombre_tipo_guia?.replace(/_/g, ' ') ??
        cabecera.codigo_tipo_guia ??
        '—';
      const motivo =
        cabecera.nombre_motivo_traslado?.replace(/_/g, ' ') ??
        cabecera.codigo_motivo_traslado ??
        '—';
      const modalidad =
        cabecera.nombre_modalidad_traslado?.replace(/_/g, ' ') ??
        cabecera.codigo_modalidad_traslado ??
        '—';

      y = this.kv(doc, left, y, pageWidth, [
        ['Fecha emisión', cabecera.fecha?.slice(0, 10) ?? '—'],
        ['Fecha traslado', cabecera.fecha_traslado?.slice(0, 10) ?? '—'],
        ['Tipo', tipoLabel],
        ['Motivo', motivo],
        ['Modalidad', modalidad],
        [
          'Peso / bultos',
          `${cabecera.peso_bruto ?? '—'} ${cabecera.nombre_unidad_medida ?? 'kg'} · ${cabecera.numero_bultos ?? '—'} bultos`,
        ],
      ]);

      y += 8;
      doc.font('Helvetica-Bold').fontSize(10).text('Destinatario', left, y);
      y += 14;
      doc
        .font('Helvetica')
        .fontSize(9)
        .text(cabecera.nombre_destinatario ?? '—', left, y, {
          width: pageWidth,
        });
      y += 13;
      doc.text(
        `Doc: ${cabecera.documento_destinatario ?? '—'}`,
        left,
        y,
        { width: pageWidth },
      );
      y += 18;

      doc.font('Helvetica-Bold').fontSize(10).text('Traslado', left, y);
      y += 14;
      doc
        .font('Helvetica')
        .fontSize(9)
        .text(
          `Origen: ${cabecera.direccion_origen ?? '—'} (${cabecera.ubigeo_origen ?? '—'} · ${cabecera.nombre_distrito_origen ?? ''})`,
          left,
          y,
          { width: pageWidth },
        );
      y += 13;
      doc.text(
        `Destino: ${cabecera.direccion_llegada ?? '—'} (${cabecera.ubigeo_llegada ?? '—'} · ${cabecera.nombre_distrito_llegada ?? ''})`,
        left,
        y,
        { width: pageWidth },
      );
      y += 13;

      if (cabecera.codigo_modalidad_traslado === '02') {
        doc.text(
          `Chofer: ${cabecera.nombre_chofer ?? '—'} · Doc ${cabecera.documento_chofer ?? '—'} · Lic ${cabecera.licencia_chofer ?? '—'}`,
          left,
          y,
          { width: pageWidth },
        );
        y += 13;
        doc.text(`Vehículo: ${cabecera.placa_vehiculo ?? '—'}`, left, y, {
          width: pageWidth,
        });
        y += 13;
      } else {
        doc.text(
          `Transportista: ${cabecera.nombre_transportista ?? '—'} · ${cabecera.documento_transportista ?? ''}`,
          left,
          y,
          { width: pageWidth },
        );
        y += 13;
      }

      if (cabecera.observaciones?.trim()) {
        y += 4;
        doc
          .font('Helvetica')
          .fontSize(9)
          .text(`Obs.: ${cabecera.observaciones.trim()}`, left, y, {
            width: pageWidth,
          });
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

      doc.rect(left, y, pageWidth, 18).fill('#F3F4F6');
      doc.fillColor('#111827').font('Helvetica-Bold').fontSize(8);
      doc.text('#', xs.item + 4, y + 5, { width: cols.item - 6 });
      doc.text('Cant.', xs.cant + 2, y + 5, { width: cols.cant - 4 });
      doc.text('Und.', xs.und + 2, y + 5, { width: cols.und - 4 });
      doc.text('Código', xs.codigo + 2, y + 5, { width: cols.codigo - 4 });
      doc.text('Descripción', xs.desc + 2, y + 5, { width: cols.desc - 4 });
      y += 18;

      doc.font('Helvetica').fontSize(8).fillColor('#111827');
      for (const detalle of detalles) {
        const desc =
          detalle.descripcion?.trim() ||
          detalle.nombre_producto ||
          `Producto ${detalle.id_producto}`;
        const rowH = Math.max(
          16,
          doc.heightOfString(desc, { width: cols.desc - 6 }) + 8,
        );

        if (y + rowH > doc.page.height - doc.page.margins.bottom - 40) {
          doc.addPage();
          y = doc.page.margins.top;
        }

        doc.text(String(detalle.item ?? ''), xs.item + 4, y + 4, {
          width: cols.item - 6,
        });
        doc.text(String(detalle.cantidad ?? ''), xs.cant + 2, y + 4, {
          width: cols.cant - 4,
        });
        doc.text(detalle.nombre_unidad_medida ?? '—', xs.und + 2, y + 4, {
          width: cols.und - 4,
        });
        doc.text(detalle.codigo_producto ?? '—', xs.codigo + 2, y + 4, {
          width: cols.codigo - 4,
        });
        doc.text(desc, xs.desc + 2, y + 4, { width: cols.desc - 6 });
        y += rowH;
        doc
          .moveTo(left, y)
          .lineTo(right, y)
          .strokeColor('#E5E7EB')
          .stroke();
      }

      y += 20;
      doc
        .font('Helvetica')
        .fontSize(8)
        .fillColor('#6B7280')
        .text(
          `Estado SUNAT: ${cabecera.nombre_estado_sunat ?? 'PENDIENTE'}${
            cabecera.hash_documento ? ` · Hash: ${cabecera.hash_documento}` : ''
          }`,
          left,
          y,
          { width: pageWidth },
        );

      doc.end();
    });
  }

  private kv(
    doc: InstanceType<typeof PDFDocument>,
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
      doc.font('Helvetica').fontSize(8).fillColor('#6B7280');
      doc.text(leftRow[0], left, rowY, { width: colW - 8 });
      if (rightRow) {
        doc.text(rightRow[0], left + colW, rowY, { width: colW - 8 });
      }
      doc.font('Helvetica').fontSize(9).fillColor('#111827');
      doc.text(leftRow[1], left, rowY + 11, { width: colW - 8 });
      if (rightRow) {
        doc.text(rightRow[1], left + colW, rowY + 11, { width: colW - 8 });
      }
      rowY += 28;
    }
    return rowY;
  }
}
