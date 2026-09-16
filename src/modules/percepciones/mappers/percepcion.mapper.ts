import { Injectable } from '@nestjs/common';
import type { FacturacionApisperuPayload } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import type { PercepcionCompletoResult, PercepcionDetalleRegistro, PercepcionRegistro } from '../interfaces/percepcion.interface';

@Injectable()
export class PercepcionMapper {
  mapToPerceptionPayload(
    doc: PercepcionCompletoResult,
    empresa: {
      ruc: string;
      razon_social: string;
      nombre_comercial: string | null;
      direccion: string | null;
      nombre_provincia: string | null;
      nombre_departamento: string | null;
      nombre_distrito: string | null;
      codigo_ubigeo: string | null;
    },
    cliente: {
      documento: string;
      nombre: string;
      tipo_documento: string | null;
    },
  ): FacturacionApisperuPayload {
    const cabecera = doc.registro;
    if (!cabecera) throw new Error('Percepción inválida');

    const razonSocial = empresa.razon_social?.trim() || empresa.nombre_comercial?.trim() || '';

    return {
      serie: cabecera.serie,
      correlativo: this.parseCorrelativo(cabecera.numero),
      fechaEmision: this.formatFecha(cabecera.fecha_emision),
      company: {
        ruc: empresa.ruc,
        razonSocial,
        nombreComercial: empresa.nombre_comercial?.trim() || razonSocial,
        address: {
          direccion: (empresa.direccion ?? '').trim(),
          provincia: (empresa.nombre_provincia ?? '').trim().toUpperCase(),
          departamento: (empresa.nombre_departamento ?? '').trim().toUpperCase(),
          distrito: (empresa.nombre_distrito ?? '').trim().toUpperCase(),
          ubigueo: (empresa.codigo_ubigeo ?? '').trim(),
        },
      },
      proveedor: {
        tipoDoc: this.mapTipoDoc(cliente.tipo_documento, cliente.documento),
        numDoc: cliente.documento,
        rznSocial: cliente.nombre || 'CLIENTE',
      },
      regimen: cabecera.regimen,
      tasa: cabecera.tasa,
      impPercibido: cabecera.monto_percibido,
      impCobrado: cabecera.monto_cobrado,
      observacion: cabecera.observacion ?? '',
      details: (doc.registro as PercepcionRegistro & { detalles?: PercepcionDetalleRegistro[] }).detalles?.map(
        (d) => ({
          tipoDoc: d.tipo_doc,
          numDoc: d.num_doc,
          fechaEmision: this.formatFecha(d.fecha_emision),
          fechaPercepcion: this.formatFecha(d.fecha_percepcion),
          moneda: d.moneda,
          impTotal: d.imp_total,
          impPercibido: d.imp_percibido,
          impCobrar: d.imp_cobrar,
          cobros: [
            {
              moneda: d.moneda,
              fecha: this.formatFecha(d.fecha_percepcion),
              importe: d.imp_percibido,
            },
          ],
          tipoCambio: {
            fecha: this.formatFecha(d.tipo_cambio_fecha ?? d.fecha_percepcion),
            factor: d.tipo_cambio_factor ?? 1,
            monedaObj: d.tipo_cambio_moneda_obj ?? 'PEN',
            monedaRef: d.tipo_cambio_moneda_ref ?? 'PEN',
          },
        }),
      ) ?? [],
    };
  }

  private mapTipoDoc(tipoDocumento?: string | null, numDoc?: string): string {
    const tipo = (tipoDocumento ?? '').toUpperCase();
    if (tipo.includes('RUC') || (numDoc?.length ?? 0) === 11) return '6';
    if (tipo.includes('DNI') || (numDoc?.length ?? 0) === 8) return '1';
    if (tipo.includes('CE')) return '4';
    return '6';
  }

  private parseCorrelativo(numero: string): string {
    const limpio = numero.replace(/^0+/, '') || '0';
    return String(Number.parseInt(limpio, 10));
  }

  private formatFecha(fecha: string | null | undefined): string {
    if (!fecha) return '';
    const base = fecha.includes('T') ? fecha.slice(0, 10) : fecha.slice(0, 10);
    return `${base}T00:00:00-05:00`;
  }
}
