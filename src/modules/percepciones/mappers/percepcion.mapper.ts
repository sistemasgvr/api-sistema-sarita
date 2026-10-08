import { receptorSunat, rucSunat, normalizarCodigoSunat, correlativoSunat, fechaHoraSunat } from '../../../common/helpers/sunat-datos.helper';
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
        ...receptorSunat(cliente.tipo_documento, cliente.documento),
        rznSocial: cliente.nombre?.trim() || 'CLIENTE',
      },
      regimen: cabecera.regimen,
      tasa: cabecera.tasa,
      impPercibido: cabecera.monto_percibido,
      impCobrado: cabecera.monto_cobrado,
      observacion: cabecera.observacion ?? '',
      details: (doc.registro as PercepcionRegistro & { detalles?: PercepcionDetalleRegistro[] }).detalles?.map(
        (d) => ({
          tipoDoc: normalizarCodigoSunat(d.tipo_doc),
          numDoc: normalizarCodigoSunat(d.num_doc),
          fechaEmision: this.formatFecha(d.fecha_emision),
          fechaPercepcion: this.formatFecha(d.fecha_percepcion),
          moneda: normalizarCodigoSunat(d.moneda),
          impTotal: d.imp_total,
          impPercibido: d.imp_percibido,
          impCobrar: d.imp_cobrar,
          cobros: [
            {
              moneda: normalizarCodigoSunat(d.moneda),
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

  private parseCorrelativo(numero: string): string {
    return correlativoSunat(numero);
  }

  private formatFecha(fecha: string | null | undefined): string {
    return fechaHoraSunat(fecha);
  }
}
