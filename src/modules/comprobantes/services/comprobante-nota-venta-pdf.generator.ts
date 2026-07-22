import { Injectable, Logger } from '@nestjs/common';
import PDFDocument from 'pdfkit';
import type { ComprobanteCompletoResult } from '../interfaces/comprobante.interface';

interface EmpresaEmisora {
  ruc: string;
  razon_social?: string | null;
  nombre_comercial?: string | null;
  direccion?: string | null;
}

interface ClienteReceptor {
  nombre_tipo_documento?: string | null;
  numero_documento?: string | null;
  razon_social?: string | null;
  nombres?: string | null;
  apellido_paterno?: string | null;
  apellido_materno?: string | null;
  direccion?: string | null;
}

/**
 * PDF A4 local para Venta sin documento (documento interno, no CPE).
 * Layout alineado a boleta A4: cabecera 3 columnas, caja cliente, tabla bordada y totales.
 */
@Injectable()
export class ComprobanteNotaVentaPdfGenerator {
  private readonly logger = new Logger(ComprobanteNotaVentaPdfGenerator.name);

  async generarA4(
    comprobante: ComprobanteCompletoResult,
    empresa: EmpresaEmisora,
    cliente: ClienteReceptor,
    logoBase64?: string | null,
  ): Promise<Buffer> {
    const cabecera = comprobante.registro;
    if (!cabecera) {
      throw new Error('Comprobante inválido');
    }

    const detalles = comprobante.detalles ?? [];
    const clienteNombre = this.resolveClienteNombre(cliente, cabecera.nombre_cliente);
    const clienteDoc =
      (cliente.numero_documento ?? cabecera.documento_cliente ?? '').trim() || '—';
    const clienteDocTipo = this.resolveDocTipoLabel(cliente, clienteDoc);
    const clienteDireccion = (cliente.direccion ?? '').trim() || 'S/N';
    const serieNumero = `${cabecera.serie}-${cabecera.numero}`;
    const empresaNombre =
      empresa.razon_social?.trim() ||
      empresa.nombre_comercial?.trim() ||
      'EMPRESA';
    const empresaDireccion = (empresa.direccion ?? '').trim();
    const monedaLabel = this.resolveMonedaLabel(cabecera.codigo_moneda);
    const valorVenta = Number(cabecera.valor_venta ?? 0);
    const igv = Number(cabecera.igv ?? 0);
    const total = Number(cabecera.total_importe ?? 0);

    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 36,
        info: {
          Title: `Venta sin documento ${serieNumero}`,
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
      const bottomLimit = doc.page.height - doc.page.margins.bottom - 24;

      // --- Columnas tabla ---
      const cols = {
        item: 28,
        cant: 52,
        codigo: 70,
        desc: 0, // flex
        vu: 54,
        pu: 54,
        sub: 54,
        tot: 54,
      };
      cols.desc =
        pageWidth -
        (cols.item + cols.cant + cols.codigo + cols.vu + cols.pu + cols.sub + cols.tot);

      const colXs = (() => {
        let x = left;
        const map: Record<keyof typeof cols, number> = {
          item: x,
          cant: (x += cols.item),
          codigo: (x += cols.cant),
          desc: (x += cols.codigo),
          vu: (x += cols.desc),
          pu: (x += cols.vu),
          sub: (x += cols.pu),
          tot: (x += cols.sub),
        };
        return map;
      })();

      let y = doc.page.margins.top;

      // ========== CABECERA ==========
      const headerTop = y;
      const logoBoxW = 95;
      const centerX = left + logoBoxW + 8;
      const boxW = 168;
      const boxX = right - boxW;
      const centerW = boxX - centerX - 10;

      // Logo
      let logoBottom = headerTop;
      if (logoBase64) {
        try {
          const logoBuf = Buffer.from(logoBase64.replace(/\s/g, ''), 'base64');
          doc.image(logoBuf, left, headerTop, { fit: [logoBoxW, 58] });
          logoBottom = headerTop + 62;
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : String(error);
          this.logger.warn(`No se pudo incrustar logo en NV A4: ${message}`);
        }
      }

      // Datos empresa (centro)
      doc.fillColor('#111111');
      doc.font('Helvetica-Bold').fontSize(10);
      doc.text(empresaNombre, centerX, headerTop, {
        width: centerW,
        align: 'left',
      });
      let empresaY = doc.y + 4;
      doc.font('Helvetica').fontSize(8);
      if (empresaDireccion) {
        doc.text(`Dirección: ${empresaDireccion}`, centerX, empresaY, {
          width: centerW,
          align: 'left',
        });
        empresaY = doc.y;
      }

      // Caja tipo + RUC + serie
      const boxPad = 8;
      const boxInnerW = boxW - boxPad * 2;
      let boxContentY = headerTop + boxPad;
      doc.font('Helvetica-Bold').fontSize(9);
      doc.text('VENTA SIN DOCUMENTO', boxX + boxPad, boxContentY, {
        width: boxInnerW,
        align: 'center',
      });
      boxContentY = doc.y + 4;
      doc.font('Helvetica').fontSize(9);
      doc.text(`R.U.C.: ${empresa.ruc}`, boxX + boxPad, boxContentY, {
        width: boxInnerW,
        align: 'center',
      });
      boxContentY = doc.y + 6;
      doc.font('Helvetica-Bold').fontSize(12);
      doc.text(serieNumero, boxX + boxPad, boxContentY, {
        width: boxInnerW,
        align: 'center',
      });
      const boxBottom = Math.max(doc.y + boxPad, headerTop + 58);
      doc
        .lineWidth(1)
        .strokeColor('#111111')
        .rect(boxX, headerTop, boxW, boxBottom - headerTop)
        .stroke();

      y = Math.max(logoBottom, empresaY, boxBottom) + 12;

      // ========== CAJA CLIENTE ==========
      const clientePad = 8;
      const clienteInnerW = pageWidth - clientePad * 2;
      const halfW = clienteInnerW / 2;
      const clienteTop = y;
      let cy = clienteTop + clientePad;

      const drawClientePair = (
        leftLabel: string,
        leftValue: string,
        rightLabel: string,
        rightValue: string,
      ) => {
        doc.font('Helvetica-Bold').fontSize(8);
        const leftLabelW = doc.widthOfString(leftLabel);
        doc.text(leftLabel, left + clientePad, cy, { lineBreak: false });
        doc.font('Helvetica').fontSize(8);
        doc.text(leftValue, left + clientePad + leftLabelW + 3, cy, {
          width: halfW - leftLabelW - 6,
          lineBreak: false,
        });

        doc.font('Helvetica-Bold').fontSize(8);
        const rightLabelW = doc.widthOfString(rightLabel);
        const rightStart = left + clientePad + halfW;
        doc.text(rightLabel, rightStart, cy, { lineBreak: false });
        doc.font('Helvetica').fontSize(8);
        doc.text(rightValue, rightStart + rightLabelW + 3, cy, {
          width: halfW - rightLabelW - 6,
          lineBreak: false,
        });
        cy += 14;
      };

      drawClientePair(
        'Razón Social:',
        clienteNombre,
        `${clienteDocTipo}:`,
        clienteDoc,
      );
      drawClientePair(
        'Fecha Emisión:',
        this.formatFecha(cabecera.fecha),
        'Dirección:',
        clienteDireccion,
      );

      doc.font('Helvetica-Bold').fontSize(8);
      const monLabel = 'Tipo Moneda:';
      const monLabelW = doc.widthOfString(monLabel);
      doc.text(monLabel, left + clientePad, cy, { lineBreak: false });
      doc.font('Helvetica').fontSize(8);
      doc.text(monedaLabel, left + clientePad + monLabelW + 3, cy, {
        lineBreak: false,
      });
      cy += 10;

      const clienteBottom = cy + 4;
      doc
        .lineWidth(1)
        .strokeColor('#111111')
        .rect(left, clienteTop, pageWidth, clienteBottom - clienteTop)
        .stroke();

      y = clienteBottom + 10;

      // ========== TABLA ==========
      const headerH = 18;
      const ensureSpace = (needed: number) => {
        if (y + needed > bottomLimit) {
          doc.addPage();
          y = doc.page.margins.top;
          drawTableHeader();
        }
      };

      const drawTableHeader = () => {
        doc.rect(left, y, pageWidth, headerH).strokeColor('#111111').stroke();
        const headers: Array<{
          key: keyof typeof cols;
          label: string;
          align?: 'left' | 'center' | 'right';
        }> = [
          { key: 'item', label: 'ITEM', align: 'center' },
          { key: 'cant', label: 'CANTIDAD', align: 'center' },
          { key: 'codigo', label: 'CÓDIGO', align: 'center' },
          { key: 'desc', label: 'DESCRIPCIÓN', align: 'center' },
          { key: 'vu', label: 'V/U', align: 'center' },
          { key: 'pu', label: 'P/U', align: 'center' },
          { key: 'sub', label: 'SUBTOTAL', align: 'center' },
          { key: 'tot', label: 'TOTAL', align: 'center' },
        ];

        doc.font('Helvetica-Bold').fontSize(7).fillColor('#111111');
        for (const h of headers) {
          doc.text(h.label, colXs[h.key], y + 5, {
            width: cols[h.key],
            align: h.align ?? 'center',
          });
        }

        // líneas verticales
        let vx = left;
        for (const key of Object.keys(cols) as Array<keyof typeof cols>) {
          if (key !== 'item') {
            doc
              .moveTo(vx, y)
              .lineTo(vx, y + headerH)
              .stroke();
          }
          vx += cols[key];
        }

        y += headerH;
      };

      drawTableHeader();

      const drawRowBorders = (rowY: number, rowH: number) => {
        doc.rect(left, rowY, pageWidth, rowH).stroke();
        let vx = left;
        for (const key of Object.keys(cols) as Array<keyof typeof cols>) {
          if (key !== 'item') {
            doc
              .moveTo(vx, rowY)
              .lineTo(vx, rowY + rowH)
              .stroke();
          }
          vx += cols[key];
        }
      };

      doc.font('Helvetica').fontSize(7.5);
      for (let i = 0; i < detalles.length; i++) {
        const detalle = detalles[i];
        const nombre =
          detalle.descripcion?.trim() ||
          detalle.nombre_producto ||
          `Producto ${detalle.id_producto}`;
        const unidad = (detalle.nombre_unidad_medida ?? 'NIU').trim() || 'NIU';
        const cant = Number(detalle.cantidad ?? 0);
        const pu = Number(detalle.precio_unitario ?? 0);
        const lineValor = Number(detalle.valor_venta ?? 0);
        const importe = Number(detalle.importe ?? 0);
        const vu = cant > 0 ? lineValor / cant : lineValor;
        const codigo = (detalle.codigo_producto ?? '').trim() || '—';
        const itemN = detalle.item ?? i + 1;

        const pad = 3;
        const descH = doc.heightOfString(nombre, {
          width: cols.desc - pad * 2,
        });
        const rowH = Math.max(16, descH + pad * 2);

        ensureSpace(rowH + 4);
        const rowY = y;

        drawRowBorders(rowY, rowH);

        const midY = rowY + (rowH - 9) / 2;
        doc.font('Helvetica').fontSize(7.5).fillColor('#111111');
        doc.text(String(itemN), colXs.item, midY, {
          width: cols.item,
          align: 'center',
        });
        doc.text(`${cant.toFixed(2)} ${unidad}`, colXs.cant + pad, midY, {
          width: cols.cant - pad * 2,
          align: 'center',
        });
        doc.text(codigo, colXs.codigo + pad, midY, {
          width: cols.codigo - pad * 2,
          align: 'left',
        });
        doc.text(nombre, colXs.desc + pad, rowY + pad, {
          width: cols.desc - pad * 2,
          align: 'left',
        });
        doc.text(`S/ ${this.money(vu)}`, colXs.vu + pad, midY, {
          width: cols.vu - pad * 2,
          align: 'right',
        });
        doc.text(`S/ ${this.money(pu)}`, colXs.pu + pad, midY, {
          width: cols.pu - pad * 2,
          align: 'right',
        });
        doc.text(`S/ ${this.money(lineValor)}`, colXs.sub + pad, midY, {
          width: cols.sub - pad * 2,
          align: 'right',
        });
        doc.text(`S/ ${this.money(importe)}`, colXs.tot + pad, midY, {
          width: cols.tot - pad * 2,
          align: 'right',
        });

        y = rowY + rowH;
      }

      if (detalles.length === 0) {
        ensureSpace(24);
        drawRowBorders(y, 20);
        doc
          .font('Helvetica')
          .fontSize(8)
          .fillColor('#666666')
          .text('Sin ítems', left, y + 6, { width: pageWidth, align: 'center' });
        y += 20;
      }

      y += 14;
      ensureSpace(110);

      // ========== PIE: info adicional + totales ==========
      const footTop = y;
      const totalsW = 210;
      const infoW = pageWidth - totalsW - 16;

      doc.font('Helvetica-Bold').fontSize(9).fillColor('#111111');
      doc.text('Información Adicional', left, footTop);
      let infoY = doc.y + 6;
      doc.font('Helvetica').fontSize(8);
      doc.text('Forma de Pago: Contado', left, infoY);
      infoY = doc.y + 3;
      if (cabecera.glosa?.trim()) {
        doc.text(`Glosa: ${cabecera.glosa.trim()}`, left, infoY, {
          width: infoW,
        });
        infoY = doc.y + 3;
      }
      doc
        .font('Helvetica')
        .fontSize(7)
        .fillColor('#666666')
        .text(
          'Documento interno.',
          left,
          infoY,
          { width: infoW },
        );

      const totalsX = right - totalsW;
      let ty = footTop;
      const drawTotal = (label: string, value: number, emphasize = false) => {
        doc
          .font(emphasize ? 'Helvetica-Bold' : 'Helvetica')
          .fontSize(emphasize ? 10 : 9)
          .fillColor('#111111');
        doc.text(label, totalsX, ty, { width: 100, align: 'right' });
        const valueText = `S/ ${this.money(value)}`;
        doc.text(valueText, totalsX + 108, ty, { width: 102, align: 'right' });
        const lineY = doc.y + 2;
        doc
          .moveTo(totalsX + 108, lineY)
          .lineTo(right, lineY)
          .strokeColor('#111111')
          .lineWidth(emphasize ? 1.2 : 0.6)
          .stroke();
        ty = lineY + 8;
      };

      drawTotal('Op. Gravadas:', valorVenta);
      drawTotal('I.G.V.:', igv);
      drawTotal('Precio Venta:', total, true);

      doc.end();
    });
  }

  private resolveClienteNombre(
    cliente: ClienteReceptor,
    fallback?: string | null,
  ) {
    return (
      cliente.razon_social?.trim() ||
      [cliente.nombres, cliente.apellido_paterno, cliente.apellido_materno]
        .filter(Boolean)
        .join(' ')
        .trim() ||
      fallback?.trim() ||
      'CLIENTES VARIOS'
    );
  }

  private resolveDocTipoLabel(cliente: ClienteReceptor, numero: string) {
    const tipo = (cliente.nombre_tipo_documento ?? '').toUpperCase();
    if (tipo.includes('RUC')) return 'RUC';
    if (tipo.includes('DNI')) return 'DNI';
    if (/^\d{11}$/.test(numero)) return 'RUC';
    if (/^\d{8}$/.test(numero)) return 'DNI';
    return 'Doc';
  }

  private resolveMonedaLabel(codigo?: string | null) {
    const c = (codigo ?? 'PEN').toUpperCase();
    if (c === 'PEN' || c === '604') return 'SOLES';
    if (c === 'USD' || c === '840') return 'DÓLARES';
    return c;
  }

  private formatFecha(fecha: string) {
    const iso = fecha.includes('T') ? fecha.slice(0, 10) : fecha.slice(0, 10);
    const [y, m, d] = iso.split('-');
    return `${d}/${m}/${y}`;
  }

  private money(value: number) {
    return new Intl.NumberFormat('es-PE', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  }
}
