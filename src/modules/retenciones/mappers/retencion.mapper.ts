import { receptorSunat, rucSunat, normalizarCodigoSunat, correlativoSunat, fechaHoraSunat } from '../../../common/helpers/sunat-datos.helper';
import { Injectable } from '@nestjs/common';
import type { FacturacionApisperuPayload } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import type { RetencionCompletoResult, RetencionDetalleRegistro, RetencionRegistro } from '../interfaces/retencion.interface';

@Injectable()
export class RetencionMapper {
  mapToRetentionPayload(
    doc: RetencionCompletoResult,
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
    proveedor: {
      documento: string;
      nombre: string;
      tipo_documento: string | null;
    },
  ): FacturacionApisperuPayload {
    const cabecera = doc.registro;
    if (!cabecera) throw new Error('Retención inválida');

    const razonSocial = empresa.razon_social?.trim() || empresa.nombre_comercial?.trim() || '';

    return {
      serie: normalizarCodigoSunat(cabecera.serie),
      correlativo: this.parseCorrelativo(cabecera.numero),
      fechaEmision: this.formatFecha(cabecera.fecha_emision),
      company: {
        ruc: rucSunat(empresa.ruc),
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
        ...receptorSunat(proveedor.tipo_documento, proveedor.documento),
        rznSocial: proveedor.nombre?.trim() || 'PROVEEDOR',
      },
      regimen: cabecera.regimen,
      tasa: cabecera.tasa,
      impRetenido: cabecera.monto_retenido,
      impPagado: cabecera.monto_pagado,
      observacion: cabecera.observacion ?? '',
      details: (doc.registro as RetencionRegistro & { detalles?: RetencionDetalleRegistro[] }).detalles?.map(
        (d) => ({
          tipoDoc: normalizarCodigoSunat(d.tipo_doc),
          numDoc: normalizarCodigoSunat(d.num_doc),
          fechaEmision: this.formatFecha(d.fecha_emision),
          fechaRetencion: this.formatFecha(d.fecha_retencion),
          moneda: normalizarCodigoSunat(d.moneda),
          impTotal: d.imp_total,
          impRetenido: d.imp_retenido,
          impPagar: d.imp_pagar,
          pagos: [
            {
              moneda: normalizarCodigoSunat(d.moneda),
              importe: d.imp_retenido,
              fecha: this.formatFecha(d.fecha_retencion),
            },
          ],
          tipoCambio: {
            fecha: this.formatFecha(d.tipo_cambio_fecha ?? d.fecha_retencion),
            factor: d.tipo_cambio_factor ?? 1,
            monedaObj: d.tipo_cambio_moneda_obj ?? 'PEN',
            monedaRef: d.tipo_cambio_moneda_ref ?? 'PEN',
          },
        }),
      ) ?? [],
    };
  }

  private parseCorrelativo(numero: string): string {
    return correlativoSunat(numero);
  }

  private formatFecha(fecha: string | null | undefined): string {
    return fechaHoraSunat(fecha);
  }
}
