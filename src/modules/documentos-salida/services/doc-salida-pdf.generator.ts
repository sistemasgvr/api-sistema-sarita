import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Injectable, Logger } from '@nestjs/common';
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

  async generarA4(
    doc: DocumentoSalidaCompletoResult,
    empresa: EmpresaEmisora,
  ): Promise<Buffer> {
    const cabecera = doc.registro;
    if (!cabecera) {
      throw new Error('Documento de salida inválido');
    }

    const detalles = cabecera.detalle ?? [];
    const esGre = Boolean(cabecera.serie && cabecera.numero_sunat);
    const tituloDoc = esGre ? 'GUÍA DE REMISIÓN' : 'ORDEN DE SALIDA';
    const serieNumero = esGre
      ? `${cabecera.serie}-${cabecera.numero_sunat}`
      : cabecera.numero;
    const empresaNombre =
      empresa.razon_social?.trim() ||
      empresa.nombre_comercial?.trim() ||
      'EMPRESA';
    const logo = await this.cargarLogo();

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

      // El bloque de datos de la empresa se corre a la derecha del logo.
      let textoX = left;
      let alturaCabecera = 0;
      if (logo) {
        pdf.image(logo.buffer, left, y, { width: LOGO_ANCHO_PT });
        textoX = left + LOGO_ANCHO_PT + 12;
        alturaCabecera = logo.alto;
      }
      const anchoTexto = right - 180 - textoX;

      pdf
        .font('Helvetica-Bold')
        .fontSize(11)
        .text(empresaNombre, textoX, y, { width: anchoTexto });
      pdf
        .font('Helvetica')
        .fontSize(9)
        .text(`RUC: ${empresa.ruc}`, textoX, y + 16, { width: anchoTexto });
      if (empresa.direccion?.trim()) {
        pdf.text(empresa.direccion.trim(), textoX, y + 30, {
          width: anchoTexto,
        });
      }

      const boxX = right - 170;
      pdf.roundedRect(boxX, y, 170, 58, 4).stroke('#333333');
      pdf
        .font('Helvetica-Bold')
        .fontSize(10)
        .text(tituloDoc, boxX, y + 8, { width: 170, align: 'center' });
      pdf
        .font('Helvetica')
        .fontSize(8)
        .text(
          cabecera.nombre_tipo_orden?.replace(/_/g, ' ') ?? '—',
          boxX,
          y + 24,
          {
            width: 170,
            align: 'center',
          },
        );
      pdf
        .font('Helvetica-Bold')
        .fontSize(12)
        .text(serieNumero ?? '—', boxX, y + 38, {
          width: 170,
          align: 'center',
        });

      y += Math.max(78, alturaCabecera + 12);

      const motivo =
        cabecera.nombre_motivo_traslado?.replace(/_/g, ' ') ??
        cabecera.codigo_motivo_traslado ??
        '—';
      const modalidad =
        cabecera.nombre_modalidad_traslado?.replace(/_/g, ' ') ??
        cabecera.codigo_modalidad_traslado ??
        '—';

      y = this.kv(pdf, left, y, pageWidth, [
        ['Fecha emisión', cabecera.fecha?.slice(0, 10) ?? '—'],
        ['Fecha traslado', cabecera.fecha_traslado?.slice(0, 10) ?? '—'],
        ['Estado', cabecera.nombre_estado_ciclo ?? '—'],
        ['Motivo', motivo],
        ['Modalidad', modalidad],
        [
          'Peso bruto',
          cabecera.peso_bruto != null
            ? `${cabecera.peso_bruto} ${cabecera.nombre_unidad_medida ?? 'kg'}`
            : '—',
        ],
        [
          'N° de bultos',
          cabecera.numero_bultos != null ? String(cabecera.numero_bultos) : '—',
        ],
      ]);

      y += 8;
      // En recarga/retorno de planta externa la carga va (o vuelve) del
      // proveedor: él ES el destinatario del documento, no un tercero aparte.
      const esPlantaExterna = cabecera.nombre_tipo_orden === 'RECARGA_PLANTA_EXTERNA';
      const destLabel = esPlantaExterna
        ? 'Destinatario (planta externa)'
        : cabecera.nombre_destinatario || cabecera.nombre_cliente
          ? 'Destinatario'
          : cabecera.nombre_proveedor
            ? 'Proveedor'
            : 'Almacén destino';
      pdf.font('Helvetica-Bold').fontSize(10).text(destLabel, left, y);
      y += 14;
      pdf
        .font('Helvetica')
        .fontSize(9)
        .text(
          (esPlantaExterna
            ? cabecera.nombre_proveedor
            : (cabecera.nombre_destinatario ??
              cabecera.nombre_cliente ??
              cabecera.nombre_proveedor)) ??
            cabecera.nombre_almacen ??
            '—',
          left,
          y,
          { width: pageWidth },
        );
      y += 13;
      const documentoDestino = esPlantaExterna
        ? cabecera.documento_proveedor
        : cabecera.documento_destinatario;
      if (documentoDestino) {
        pdf.text(`Doc: ${documentoDestino}`, left, y, {
          width: pageWidth,
        });
        y += 13;
      }
      // Dirección de entrega: es el dato que se captura en el modal al crear la
      // orden y hasta ahora no llegaba al papel. Va en toda orden, no solo en GRE.
      // En una GRE el punto de llegada ya se imprime en el bloque "Traslado", y
      // sale de la misma dirección de entrega: repetirlo era ruido. Este bloque
      // solo aparece cuando el documento NO trae ese destino.
      const direccionEntrega = cabecera.direccion_entrega?.trim();
      const destinoYaImpreso =
        esGre && Boolean(cabecera.direccion_llegada?.trim());
      if (direccionEntrega && !destinoYaImpreso) {
        y += 8;
        pdf
          .font('Helvetica-Bold')
          .fontSize(10)
          .text('Dirección de entrega', left, y);
        y += 14;
        pdf
          .font('Helvetica')
          .fontSize(9)
          .text(direccionEntrega, left, y, { width: pageWidth });
        y += pdf.heightOfString(direccionEntrega, { width: pageWidth }) + 2;

        const zona = [cabecera.nombre_distrito_entrega, cabecera.ubigeo_entrega]
          .filter(Boolean)
          .join(' · ');
        if (zona) {
          pdf.fillColor('#6B7280').text(zona, left, y, { width: pageWidth });
          pdf.fillColor('#111827');
          y += 13;
        }
        if (cabecera.referencia_entrega?.trim()) {
          const referencia = `Ref.: ${cabecera.referencia_entrega.trim()}`;
          pdf
            .fillColor('#6B7280')
            .text(referencia, left, y, { width: pageWidth });
          pdf.fillColor('#111827');
          y += pdf.heightOfString(referencia, { width: pageWidth }) + 2;
        }
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
          pdf.text(`Vehículo: ${cabecera.placa_vehiculo ?? '—'}`, left, y, {
            width: pageWidth,
          });
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
          .text(`Obs.: ${cabecera.observaciones.trim()}`, left, y, {
            width: pageWidth,
          });
        y += 16;
      }

      y += 8;
      const cols = {
        item: 24,
        tipo: 54,
        cant: 44,
        und: 44,
        codigo: 74,
        desc: pageWidth - 24 - 54 - 44 - 44 - 74,
      };
      const xs = {
        item: left,
        tipo: left + cols.item,
        cant: left + cols.item + cols.tipo,
        und: left + cols.item + cols.tipo + cols.cant,
        codigo: left + cols.item + cols.tipo + cols.cant + cols.und,
        desc: left + cols.item + cols.tipo + cols.cant + cols.und + cols.codigo,
      };

      pdf.rect(left, y, pageWidth, 18).fill('#F3F4F6');
      pdf.fillColor('#111827').font('Helvetica-Bold').fontSize(8);
      pdf.text('#', xs.item + 4, y + 5, { width: cols.item - 6 });
      pdf.text('Tipo', xs.tipo + 2, y + 5, { width: cols.tipo - 4 });
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
          (detalle.id_producto != null
            ? `Producto ${detalle.id_producto}`
            : 'Ítem');
        const codigo =
          detalle.codigo_balon?.trim() || detalle.codigo_producto || '—';
        const rowH = Math.max(
          16,
          pdf.heightOfString(desc, { width: cols.desc - 6 }) + 8,
        );

        if (y + rowH > pdf.page.height - pdf.page.margins.bottom - 40) {
          pdf.addPage();
          y = pdf.page.margins.top;
        }

        pdf.text(String(detalle.item ?? ''), xs.item + 4, y + 4, {
          width: cols.item - 6,
        });
        pdf.text(
          detalle.id_balon != null ? 'Balón' : 'Producto',
          xs.tipo + 2,
          y + 4,
          {
            width: cols.tipo - 4,
          },
        );
        pdf.text(String(detalle.cantidad ?? ''), xs.cant + 2, y + 4, {
          width: cols.cant - 4,
        });
        pdf.text(detalle.nombre_unidad_medida ?? '—', xs.und + 2, y + 4, {
          width: cols.und - 4,
        });
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
