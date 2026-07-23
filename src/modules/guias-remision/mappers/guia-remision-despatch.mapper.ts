import { BadRequestException, Injectable } from '@nestjs/common';
import type { FacturacionApisperuPayload } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import type {
  GuiaRemisionCompletoResult,
  GuiaRemisionDetalleRegistro,
} from '../interfaces/guia-remision.interface';

interface EmpresaEmisora {
  ruc: string;
  razon_social?: string | null;
  nombre_comercial?: string | null;
  direccion?: string | null;
}

/**
 * Mapea GRE local → payload Greenter/APIsPERU `/despatch/send`.
 * Alineado a swagger Despatch: tipo 09 (remitente) y 31 (transportista).
 */
@Injectable()
export class GuiaRemisionDespatchMapper {
  mapToDespatchPayload(
    guia: GuiaRemisionCompletoResult,
    empresa: EmpresaEmisora,
  ): FacturacionApisperuPayload {
    const cabecera = guia.registro;

    if (!cabecera) {
      throw new BadRequestException('Guía de remisión inválida');
    }

    const detalles = guia.detalles ?? [];

    if (detalles.length === 0) {
      throw new BadRequestException('La guía no tiene ítems');
    }

    const tipoDoc = cabecera.codigo_tipo_guia;

    if (!tipoDoc || !['09', '31'].includes(tipoDoc)) {
      throw new BadRequestException(
        `Tipo de guía ${tipoDoc ?? '—'} no soportado para emisión electrónica`,
      );
    }

    const modalidad = cabecera.codigo_modalidad_traslado ?? '02';
    const ubigeoPartida = (cabecera.ubigeo_origen ?? '').trim();
    const ubigeoLlegada = (cabecera.ubigeo_llegada ?? '').trim();

    if (!ubigeoPartida || !ubigeoLlegada) {
      throw new BadRequestException(
        'Origen y destino requieren código ubigeo SUNAT (distrito)',
      );
    }

    const envio: Record<string, unknown> = {
      codTraslado: cabecera.codigo_motivo_traslado ?? '01',
      desTraslado: this.mapDesTraslado(
        cabecera.nombre_motivo_traslado,
        cabecera.codigo_motivo_traslado,
      ),
      modTraslado: modalidad,
      fecTraslado: this.formatFecha(cabecera.fecha_traslado),
      pesoTotal: Number(cabecera.peso_bruto ?? 0),
      undPesoTotal: this.mapUnidadPeso(
        cabecera.codigo_unidad_medida,
        cabecera.nombre_unidad_medida,
      ),
      numBultos: Number(cabecera.numero_bultos ?? 1),
      llegada: {
        ubigueo: ubigeoLlegada,
        direccion: (cabecera.direccion_llegada ?? 'S/N').trim() || 'S/N',
      },
      partida: {
        ubigueo: ubigeoPartida,
        direccion: (cabecera.direccion_origen ?? 'S/N').trim() || 'S/N',
      },
    };

    if (modalidad === '02') {
      const placa = (cabecera.placa_vehiculo ?? '').trim();
      const docChofer = (cabecera.documento_chofer ?? '').trim();
      const licencia = (cabecera.licencia_chofer ?? '').trim();

      if (!placa) {
        throw new BadRequestException('Transporte privado requiere placa del vehículo');
      }

      if (!docChofer) {
        throw new BadRequestException('Transporte privado requiere documento del chofer');
      }

      if (!licencia) {
        throw new BadRequestException(
          'El chofer seleccionado no tiene licencia registrada. Actualiza el chofer antes de emitir la GRE.',
        );
      }

      envio.vehiculo = { placa };
      envio.choferes = [
        {
          tipo: 'Principal',
          tipoDoc: this.mapTipoDocChofer(
            cabecera.codigo_tipo_doc_chofer,
            docChofer,
          ),
          nroDoc: docChofer,
          licencia,
          nombres: this.splitNombre(cabecera.nombre_chofer).nombres,
          apellidos: this.splitNombre(cabecera.nombre_chofer).apellidos,
        },
      ];

      // GRE-T (31) privada: la empresa emisora actúa como transportista
      if (tipoDoc === '31') {
        envio.transportista = {
          tipoDoc: '6',
          numDoc: empresa.ruc,
          rznSocial:
            empresa.razon_social?.trim() ||
            empresa.nombre_comercial?.trim() ||
            'TRANSPORTISTA',
        };
      }
    } else if (modalidad === '01') {
      const rucTrans = (cabecera.documento_transportista ?? '').trim();
      const razonTrans = (cabecera.nombre_transportista ?? '').trim();

      if (!rucTrans || rucTrans.length !== 11) {
        throw new BadRequestException(
          'Transporte público requiere RUC del transportista',
        );
      }

      envio.transportista = {
        tipoDoc: '6',
        numDoc: rucTrans,
        rznSocial: razonTrans || 'TRANSPORTISTA',
      };
    }

    const destinatarioDoc = (cabecera.documento_destinatario ?? '').trim();

    if (!destinatarioDoc) {
      throw new BadRequestException('El destinatario no tiene número de documento');
    }

    const payload: FacturacionApisperuPayload = {
      version: '2022',
      tipoDoc,
      serie: cabecera.serie,
      correlativo: this.parseCorrelativo(cabecera.numero),
      fechaEmision: this.formatFecha(cabecera.fecha),
      company: this.mapEmpresa(empresa),
      destinatario: {
        tipoDoc: this.mapTipoDocCliente(
          cabecera.nombre_tipo_doc_destinatario,
          destinatarioDoc,
        ),
        numDoc: destinatarioDoc,
        rznSocial: (cabecera.nombre_destinatario ?? 'DESTINATARIO').trim(),
      },
      envio,
      details: detalles.map((detalle, index) =>
        this.mapDetalle(detalle, index + 1),
      ),
    };

    if (tipoDoc === '31') {
      const remitenteDoc = (cabecera.documento_cliente ?? '').trim();
      if (!remitenteDoc) {
        throw new BadRequestException(
          'GRE transportista (31) requiere remitente (cliente) con documento',
        );
      }
      payload.remitente = {
        tipoDoc: this.mapTipoDocCliente(
          cabecera.nombre_tipo_doc_cliente,
          remitenteDoc,
        ),
        numDoc: remitenteDoc,
        rznSocial: (cabecera.nombre_cliente ?? 'REMITENTE').trim(),
      };
    }

    if (cabecera.observaciones?.trim()) {
      payload.observacion = cabecera.observaciones.trim();
    }

    const refs = guia.referencias ?? [];
    const mappedRefs = refs
      .filter((r) => r.serie && r.numero && r.codigo_tipo_comprobante)
      .map((r) => ({
        tipoDoc: r.codigo_tipo_comprobante as string,
        nroDoc: `${r.serie}-${this.parseCorrelativo(String(r.numero))}`,
      }));

    if (mappedRefs.length > 0) {
      payload.relDoc = mappedRefs[0];
      if (mappedRefs.length > 1) {
        payload.addDocs = mappedRefs.slice(1).map((r) => ({
          tipo: r.tipoDoc,
          nro: r.nroDoc,
        }));
      }
    }

    return payload;
  }

  private mapDetalle(detalle: GuiaRemisionDetalleRegistro, _item: number) {
    return {
      codigo:
        detalle.codigo_balon?.trim() ||
        detalle.codigo_producto ||
        String(detalle.id_producto),
      descripcion:
        detalle.glosa?.trim() ||
        detalle.descripcion?.trim() ||
        detalle.nombre_producto ||
        `Producto ${detalle.id_producto}`,
      unidad: this.mapUnidadItem(
        detalle.codigo_unidad_medida,
        detalle.nombre_unidad_medida,
      ),
      cantidad: Number(detalle.cantidad ?? 0),
    };
  }

  private mapEmpresa(empresa: EmpresaEmisora) {
    return {
      ruc: empresa.ruc,
      razonSocial: empresa.razon_social ?? empresa.nombre_comercial ?? 'Empresa',
      nombreComercial:
        empresa.nombre_comercial ?? empresa.razon_social ?? 'Empresa',
      address: {
        direccion: empresa.direccion?.trim() || 'S/N',
        provincia: 'LIMA',
        departamento: 'LIMA',
        distrito: 'LIMA',
        ubigueo: '150101',
      },
    };
  }

  private mapTipoDocCliente(tipoDocumento?: string | null, numDoc?: string) {
    const tipo = (tipoDocumento ?? '').toUpperCase();
    if (tipo.includes('RUC') || (numDoc?.length ?? 0) === 11) return '6';
    if (tipo.includes('DNI') || (numDoc?.length ?? 0) === 8) return '1';
    if (tipo.includes('CE')) return '4';
    if (tipo.includes('PAS')) return '7';
    return '6';
  }

  private mapTipoDocChofer(codigo?: string | null, numDoc?: string) {
    const c = (codigo ?? '').trim();
    if (['1', '4', '7'].includes(c)) return c;
    if ((numDoc?.length ?? 0) === 8) return '1';
    return '1';
  }

  private mapDesTraslado(nombre?: string | null, codigo?: string | null) {
    const label = (nombre ?? '').replace(/_/g, ' ').trim();
    if (label) return label;
    return (codigo ?? 'TRASLADO').trim() || 'TRASLADO';
  }

  private mapUnidadPeso(codigo?: string | null, nombre?: string | null) {
    const raw = (codigo ?? nombre ?? 'KGM').trim().toUpperCase();
    if (raw === 'KG' || raw === 'KGM' || raw.includes('KILO')) return 'KGM';
    return raw.length >= 2 && raw.length <= 4 ? raw : 'KGM';
  }

  private mapUnidadItem(codigo?: string | null, nombre?: string | null) {
    const raw = (codigo ?? nombre ?? 'NIU').trim().toUpperCase();
    if (
      raw === 'UNID' ||
      raw === 'UND' ||
      raw === 'UNI' ||
      raw === 'BOTELLAS' ||
      raw === 'BOTELLA' ||
      raw === 'BOT' ||
      raw.includes('BOTELL')
    ) {
      return 'NIU';
    }
    return raw.length >= 2 && raw.length <= 4 ? raw : 'NIU';
  }

  private splitNombre(nombreCompleto?: string | null) {
    const parts = (nombreCompleto ?? 'CHOFER').trim().split(/\s+/).filter(Boolean);
    if (parts.length === 1) {
      return { nombres: parts[0], apellidos: parts[0] };
    }
    return {
      nombres: parts[0],
      apellidos: parts.slice(1).join(' '),
    };
  }

  private parseCorrelativo(numero: string) {
    const limpio = numero.replace(/^0+/, '') || '0';
    const parsed = Number.parseInt(limpio, 10);
    if (Number.isNaN(parsed)) {
      throw new BadRequestException(`Número de guía inválido: ${numero}`);
    }
    return String(parsed);
  }

  private formatFecha(fecha: string) {
    const base = fecha.includes('T') ? fecha.slice(0, 10) : fecha.slice(0, 10);
    return `${base}T00:00:00-05:00`;
  }
}
