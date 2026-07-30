import { Injectable, Logger } from '@nestjs/common';
import PDFDocument from 'pdfkit';
import * as QRCode from 'qrcode';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import type {
  ComprobanteCompletoResult,
  ComprobanteDetalleRegistro,
} from '../interfaces/comprobante.interface';

/** Ancho ticketera 80mm en puntos PDF (72 dpi). */
const PAGE_WIDTH_PT = (80 / 25.4) * 72; // ≈ 226.77
const MARGIN_X = 10;
const CONTENT_WIDTH = PAGE_WIDTH_PT - MARGIN_X * 2;

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

@Injectable()
export class ComprobanteTicketPdfGenerator {
  private readonly logger = new Logger(ComprobanteTicketPdfGenerator.name);

  constructor(private readonly facturacionClient: FacturacionApisperuClient) {}

  async generar(
    comprobante: ComprobanteCompletoResult,
    empresa: EmpresaEmisora,
    cliente: ClienteReceptor,
    options?: { documentoInterno?: boolean; logoBase64?: string | null },
  ): Promise<Buffer> {
    const cabecera = comprobante.registro;
    const documentoInterno = options?.documentoInterno === true;

    if (!cabecera) {
      throw new Error('Comprobante inválido');
    }

    const detalles = comprobante.detalles ?? [];
    let logoBase64 = options?.logoBase64 ?? null;
    if (logoBase64 === null && !documentoInterno) {
      logoBase64 = await this.facturacionClient.obtenerLogoEmpresaBase64(
        empresa.ruc,
      );
    } else if (logoBase64 === null && documentoInterno) {
      try {
        logoBase64 = await this.facturacionClient.obtenerLogoEmpresaBase64(
          empresa.ruc,
        );
      } catch {
        logoBase64 = null;
      }
    }

    const clienteNombre =
      cliente.razon_social?.trim() ||
      [cliente.nombres, cliente.apellido_paterno, cliente.apellido_materno]
        .filter(Boolean)
        .join(' ')
        .trim() ||
      cabecera.nombre_cliente ||
      'Cliente';
    const clienteDoc =
      (cliente.numero_documento ?? cabecera.documento_cliente ?? '').trim() ||
      '—';
    const clienteTipoDoc = this.mapTipoDocumentoCliente(
      cliente.nombre_tipo_documento,
      clienteDoc,
    );
    const clienteDireccion = (cliente.direccion ?? '').trim() || 'S/N';

    const tipoNombre = (
      cabecera.nombre_tipo_comprobante ?? 'COMPROBANTE ELECTRÓNICO'
    ).toUpperCase();
    const tipoCodigo = cabecera.codigo_tipo_comprobante ?? '';
    const serieNumero = `${cabecera.serie}-${cabecera.numero}`;
    const fecha = this.formatFecha(cabecera.fecha);
    const moneda =
      (cabecera.codigo_moneda ?? 'PEN') === 'PEN' ? 'SOLES' : cabecera.codigo_moneda;
    const hash = documentoInterno ? '' : (cabecera.hash_documento ?? '').trim();

    const valorVenta = Number(cabecera.valor_venta ?? 0);
    const igv = Number(cabecera.igv ?? 0);
    const total = Number(cabecera.total_importe ?? 0);

    let qrPng: Buffer | null = null;
    if (!documentoInterno) {
      const qrPayload = [
        empresa.ruc,
        tipoCodigo || '03',
        cabecera.serie,
        this.stripLeadingZeros(cabecera.numero),
        this.moneyPlain(igv),
        this.moneyPlain(total),
        this.formatFechaIso(cabecera.fecha),
        clienteTipoDoc,
        clienteDoc === '—' ? '' : clienteDoc,
        hash,
      ].join('|');

      qrPng = await QRCode.toBuffer(qrPayload, {
        type: 'png',
        width: 140,
        margin: 1,
        errorCorrectionLevel: 'M',
      });
    }

    const estimatedHeight =
      320 +
      (logoBase64 ? 70 : 0) +
      detalles.length * 42 +
      (hash ? 36 : 0) +
      (qrPng ? 160 : 60);

    return this.renderPdf({
      width: PAGE_WIDTH_PT,
      height: Math.max(estimatedHeight, 480),
      logoBase64,
      empresaNombre:
        empresa.nombre_comercial?.trim() ||
        empresa.razon_social?.trim() ||
        'EMPRESA',
      empresaRazon: empresa.razon_social?.trim() || '',
      empresaDireccion: empresa.direccion?.trim() || 'S/N',
      empresaRuc: empresa.ruc,
      tipoNombre: documentoInterno ? 'VENTA SIN DOCUMENTO' : tipoNombre,
      tipoCodigo: documentoInterno ? 'VSD' : tipoCodigo,
      serieNumero,
      fecha,
      clienteNombre,
      clienteDoc,
      clienteDireccion,
      moneda: String(moneda),
      detalles,
      valorVenta,
      igv,
      total,
      hash,
      qrPng,
      documentoInterno,
    });
  }

  private renderPdf(ctx: {
    width: number;
    height: number;
    logoBase64: string | null;
    empresaNombre: string;
    empresaRazon: string;
    empresaDireccion: string;
    empresaRuc: string;
    tipoNombre: string;
    tipoCodigo: string;
    serieNumero: string;
    fecha: string;
    clienteNombre: string;
    clienteDoc: string;
    clienteDireccion: string;
    moneda: string;
    detalles: ComprobanteDetalleRegistro[];
    valorVenta: number;
    igv: number;
    total: number;
    hash: string;
    qrPng: Buffer | null;
    documentoInterno?: boolean;
  }): Promise<Buffer> {
    return new Promise((resolve, reject) => {
      const doc = new PDFDocument({
        size: [ctx.width, ctx.height],
        margin: 0,
        autoFirstPage: true,
        info: {
          Title: `Ticket ${ctx.serieNumero}`,
          Author: ctx.empresaNombre,
        },
      });

      const chunks: Buffer[] = [];
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', () => resolve(Buffer.concat(chunks)));
      doc.on('error', reject);

      let y = 10;

      const centerText = (
        text: string,
        opts: { size?: number; bold?: boolean; color?: string } = {},
      ) => {
        doc
          .font(opts.bold ? 'Helvetica-Bold' : 'Helvetica')
          .fontSize(opts.size ?? 8)
          .fillColor(opts.color ?? '#111111')
          .text(text, MARGIN_X, y, {
            width: CONTENT_WIDTH,
            align: 'center',
          });
        y = doc.y + 2;
      };

      const leftText = (
        text: string,
        opts: { size?: number; bold?: boolean } = {},
      ) => {
        doc
          .font(opts.bold ? 'Helvetica-Bold' : 'Helvetica')
          .fontSize(opts.size ?? 7.5)
          .fillColor('#111111')
          .text(text, MARGIN_X, y, { width: CONTENT_WIDTH, align: 'left' });
        y = doc.y + 1;
      };

      const separator = (dashed = true) => {
        y += 3;
        doc.save();
        doc.strokeColor('#333333').lineWidth(0.6);
        if (dashed) doc.dash(2, { space: 2 });
        doc
          .moveTo(MARGIN_X, y)
          .lineTo(MARGIN_X + CONTENT_WIDTH, y)
          .stroke();
        doc.undash();
        doc.restore();
        y += 5;
      };

      const row = (label: string, value: string, bold = false) => {
        const font = bold ? 'Helvetica-Bold' : 'Helvetica';
        doc.font(font).fontSize(7.5).fillColor('#111111');
        const labelW = CONTENT_WIDTH * 0.55;
        doc.text(label, MARGIN_X, y, { width: labelW, align: 'left' });
        doc.text(value, MARGIN_X + labelW, y, {
          width: CONTENT_WIDTH - labelW,
          align: 'right',
        });
        y += 11;
      };

      if (ctx.logoBase64) {
        try {
          const logoBuf = Buffer.from(
            ctx.logoBase64.replace(/\s/g, ''),
            'base64',
          );
          const logoW = Math.min(130, CONTENT_WIDTH);
          const logoH = 56;
          const logoX = MARGIN_X + (CONTENT_WIDTH - logoW) / 2;
          doc.image(logoBuf, logoX, y, {
            fit: [logoW, logoH],
            align: 'center',
            valign: 'center',
          });
          y += logoH + 6;
        } catch (error: unknown) {
          const message =
            error instanceof Error ? error.message : String(error);
          this.logger.warn(`No se pudo incrustar logo en ticket PDF: ${message}`);
        }
      }

      centerText(ctx.empresaNombre, { size: 10, bold: true });
      if (ctx.empresaRazon && ctx.empresaRazon !== ctx.empresaNombre) {
        centerText(ctx.empresaRazon, { size: 7.5 });
      }
      centerText(ctx.empresaDireccion, { size: 7 });
      centerText(`RUC ${ctx.empresaRuc}`, { size: 8, bold: true });

      separator();

      centerText(ctx.tipoNombre, { size: 8, bold: true });
      if (ctx.tipoCodigo) {
        centerText(`(${ctx.tipoCodigo})`, { size: 7 });
      }
      centerText(ctx.serieNumero, { size: 11, bold: true });
      centerText(`Fecha: ${ctx.fecha}`, { size: 7.5 });

      separator();

      leftText(`Cliente: ${ctx.clienteNombre}`, { bold: true, size: 7.5 });
      leftText(`Doc: ${ctx.clienteDoc}`);
      leftText(`Dirección: ${ctx.clienteDireccion}`);
      leftText(`Moneda: ${ctx.moneda}`);
      leftText('Forma de pago: Contado');

      separator();

      for (const detalle of ctx.detalles) {
        const nombre =
          detalle.descripcion?.trim() ||
          detalle.nombre_producto ||
          `Producto ${detalle.id_producto}`;
        const unidad = (detalle.nombre_unidad_medida ?? 'NIU').trim() || 'NIU';
        const cant = Number(detalle.cantidad ?? 0);
        const pu = Number(detalle.precio_unitario ?? 0);
        const importe = Number(detalle.importe ?? 0);
        const codigo = detalle.codigo_producto?.trim();

        leftText(nombre, { bold: true, size: 7.5 });
        if (codigo) leftText(`Cód: ${codigo}`, { size: 6.5 });
        row(`${cant.toFixed(2)} ${unidad} x S/ ${this.money(pu)}`, `S/ ${this.money(importe)}`);
        y += 2;
      }

      separator();

      row('Op. Gravadas', `S/ ${this.money(ctx.valorVenta)}`);
      row('I.G.V. (18%)', `S/ ${this.money(ctx.igv)}`);
      row('TOTAL', `S/ ${this.money(ctx.total)}`, true);

      separator(false);

      if (ctx.hash) {
        centerText('Resumen', { size: 7, bold: true });
        centerText(ctx.hash, { size: 6.5 });
      }

      if (ctx.documentoInterno) {
        centerText('Documento interno', { size: 6.5, bold: true });
        /* centerText('Documento interno — No es CPE', { size: 6.5, bold: true });
        centerText('No válido como comprobante electrónico SUNAT', {
          size: 6,
        }); */
      } else {
        centerText(
          'Representación impresa del CPE. Consulte en www.sunat.gob.pe',
          { size: 6 },
        );
      }

      if (ctx.qrPng) {
        y += 4;
        const qrSize = 100;
        const qrX = MARGIN_X + (CONTENT_WIDTH - qrSize) / 2;
        doc.image(ctx.qrPng, qrX, y, { width: qrSize, height: qrSize });
        y += qrSize + 6;
      } else {
        y += 8;
      }

      centerText('¡Gracias por su preferencia!', { size: 7 });

      doc.end();
    });
  }

  private mapTipoDocumentoCliente(tipoDocumento?: string | null, numDoc?: string) {
    const tipo = (tipoDocumento ?? '').toUpperCase();

    if (tipo.includes('RUC') || (numDoc?.length ?? 0) === 11) return '6';
    if (tipo.includes('DNI') || (numDoc?.length ?? 0) === 8) return '1';
    if (tipo.includes('CE')) return '4';
    if (tipo.includes('PAS')) return '7';

    return '6';
  }

  private formatFecha(fecha: string) {
    const iso = this.formatFechaIso(fecha);
    const [y, m, d] = iso.split('-');
    return `${d}/${m}/${y}`;
  }

  private formatFechaIso(fecha: string) {
    return fecha.includes('T') ? fecha.slice(0, 10) : fecha.slice(0, 10);
  }

  private stripLeadingZeros(numero: string) {
    return numero.replace(/^0+/, '') || '0';
  }

  private money(value: number) {
    return new Intl.NumberFormat('es-PE', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(value);
  }

  private moneyPlain(value: number) {
    return value.toFixed(2);
  }
}
