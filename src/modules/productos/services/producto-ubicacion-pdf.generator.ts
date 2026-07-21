import { Injectable } from '@nestjs/common';
import PDFDocument from 'pdfkit';

export interface ProductoUbicacionLabelItem {
  codigo_ubicacion: string;
  codigo: string;
  nombre: string;
}

const PAGE_WIDTH = 595.28;
const PAGE_HEIGHT = 841.89;
const MARGIN_X = 18;
const MARGIN_Y = 18;
const GAP_X = 8;
const GAP_Y = 8;
const COLS = 3;
/** Altura fija compacta (sin huecos internos). */
const CARD_HEIGHT = 78;
const PAD_X = 8;
const PAD_Y = 7;

function truncateText(text: string, maxChars: number): string {
  const value = text.trim();
  if (value.length <= maxChars) return value;
  return `${value.slice(0, Math.max(0, maxChars - 1))}…`;
}

@Injectable()
export class ProductoUbicacionPdfGenerator {
  generarTarjetas(items: ProductoUbicacionLabelItem[]): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({
        size: 'A4',
        margin: 0,
        info: {
          Title: 'Tarjetas de ubicación de productos',
          Author: 'Sistema Sarita',
        },
      });

      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      const cardWidth = (PAGE_WIDTH - MARGIN_X * 2 - GAP_X * (COLS - 1)) / COLS;
      const rows = Math.max(
        1,
        Math.floor((PAGE_HEIGHT - MARGIN_Y * 2 + GAP_Y) / (CARD_HEIGHT + GAP_Y)),
      );
      const cardsPerPage = COLS * rows;

      items.forEach((item, index) => {
        if (index > 0 && index % cardsPerPage === 0) {
          doc.addPage();
        }

        const pageIndex = index % cardsPerPage;
        const col = pageIndex % COLS;
        const row = Math.floor(pageIndex / COLS);
        const x = MARGIN_X + col * (cardWidth + GAP_X);
        const y = MARGIN_Y + row * (CARD_HEIGHT + GAP_Y);
        const contentWidth = cardWidth - PAD_X * 2;
        let cursorY = y + PAD_Y;

        doc
          .save()
          .lineWidth(0.9)
          .strokeColor('#787878')
          .dash(2.5, { space: 2.5 })
          .roundedRect(x, y, cardWidth, CARD_HEIGHT, 4)
          .stroke()
          .undash()
          .restore();

        doc
          .fillColor('#6b6b6b')
          .font('Helvetica')
          .fontSize(7)
          .text('UBICACIÓN', x + PAD_X, cursorY, {
            width: contentWidth,
            align: 'center',
            lineBreak: false,
          });
        cursorY += 10;

        doc
          .fillColor('#141414')
          .font('Helvetica-Bold')
          .fontSize(14)
          .text(truncateText(item.codigo_ubicacion, 18), x + PAD_X, cursorY, {
            width: contentWidth,
            align: 'center',
            lineBreak: false,
          });
        cursorY += 16;

        doc
          .moveTo(x + PAD_X + 4, cursorY)
          .lineTo(x + cardWidth - PAD_X - 4, cursorY)
          .lineWidth(0.5)
          .strokeColor('#c8c8c8')
          .stroke();
        cursorY += 5;

        doc
          .fillColor('#1e1e1e')
          .font('Helvetica-Bold')
          .fontSize(8)
          .text(truncateText(item.nombre, 56), x + PAD_X, cursorY, {
            width: contentWidth,
            align: 'center',
            height: 20,
            ellipsis: true,
          });
        cursorY += 20;

        doc
          .fillColor('#5a5a5a')
          .font('Helvetica')
          .fontSize(7.5)
          .text(`Cód: ${truncateText(item.codigo, 24)}`, x + PAD_X, cursorY, {
            width: contentWidth,
            align: 'center',
            lineBreak: false,
          });
      });

      doc.end();
    });
  }
}
