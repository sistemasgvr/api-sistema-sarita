import { receptorSunat, rucSunat, normalizarCodigoSunat, normalizarDocumentoSunat, correlativoSunat, fechaCivilSunat, fechaHoraSunat } from '../../../common/helpers/sunat-datos.helper';
import { BadRequestException, Injectable } from '@nestjs/common';
import type { FacturacionApisperuPayload } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import type {
  ComprobanteCompletoResult,
  ComprobanteDetalleRegistro,
} from '../interfaces/comprobante.interface';
import { lineasDeVenta } from '../utils/comprobante-lineas.util';

interface EmpresaEmisora {
  codigo_ubigeo?: string | null;
  nombre_distrito?: string | null;
  nombre_provincia?: string | null;
  nombre_departamento?: string | null;
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
  nombre_departamento?: string | null;
  nombre_provincia?: string | null;
  nombre_distrito?: string | null;
}

@Injectable()
export class ComprobanteInvoiceMapper {
  mapComprobanteToInvoicePayload(
    comprobante: ComprobanteCompletoResult,
    empresa: EmpresaEmisora,
    cliente: ClienteReceptor,
    ubigeoCliente = '',
  ): FacturacionApisperuPayload {
    const cabecera = comprobante.registro;

    if (!cabecera) {
      throw new BadRequestException('Comprobante inválido');
    }

    const detalles = comprobante.detalles ?? [];

    if (detalles.length === 0) {
      throw new BadRequestException('El comprobante no tiene detalles');
    }

    // A SUNAT solo viaja la venta. La garantía es dinero reembolsable que el
    // cliente deja en custodia, no una operación gravada: vive en ven_garantia
    // y llega al comprobante por JOIN, no como línea. Los comprobantes creados
    // antes de ese cambio sí guardan la línea, así que se filtra aquí.
    const detallesVenta = lineasDeVenta(detalles);

    if (detallesVenta.length === 0) {
      throw new BadRequestException(
        'El comprobante no tiene líneas de venta: solo registra garantía, que no se declara a SUNAT',
      );
    }

    const tipoDoc = normalizarCodigoSunat(cabecera.codigo_tipo_comprobante);

    if (!tipoDoc || !['01', '03', '07', '08'].includes(tipoDoc)) {
      throw new BadRequestException(
        `Tipo de comprobante ${tipoDoc ?? '—'} no soportado para emisión electrónica`,
      );
    }

    const correlativo = this.parseCorrelativo(cabecera.numero);
    const fechaEmision = this.formatFechaEmision(cabecera.fecha);
    const tipoMoneda = normalizarCodigoSunat(cabecera.codigo_moneda ?? 'PEN');
    // Si se descartó alguna línea, los totales de la cabecera ya no
    // corresponden a lo que se declara (los de un comprobante antiguo incluyen
    // la garantía), así que se recalculan desde las líneas que sí van.
    const totales = this.calcularTotales(
      detallesVenta,
      cabecera,
      detallesVenta.length === detalles.length,
    );

    const formaPago = this.mapFormaPago(
      cabecera,
      comprobante.cuotas ?? [],
      tipoMoneda,
      totales.mtoImpVenta,
    );

    const payload: FacturacionApisperuPayload = {
      ublVersion: '2.1',
      tipoOperacion: cabecera.codigo_tipo_operacion_sunat ?? '0101',
      tipoDoc,
      serie: normalizarCodigoSunat(cabecera.serie),
      correlativo,
      fechaEmision,
      formaPago,
      tipoMoneda,
      client: this.mapCliente(cliente, ubigeoCliente),
      company: this.mapEmpresa(empresa),
      mtoOperGravadas: totales.mtoOperGravadas,
      mtoOperExoneradas: totales.mtoOperExoneradas,
      mtoOperInafectas: totales.mtoOperInafectas,
      mtoIGV: totales.mtoIGV,
      valorVenta: totales.valorVenta,
      totalImpuestos: totales.totalImpuestos,
      subTotal: totales.subTotal,
      mtoImpVenta: totales.mtoImpVenta,
      details: detallesVenta.map((detalle, index) =>
        this.mapDetalle(detalle, index + 1),
      ),
    };

    if (tipoDoc === '07' || tipoDoc === '08') {
      if (!cabecera.serie_comprobante_origen || !cabecera.numero_comprobante_origen) {
        throw new BadRequestException(
          'Las notas de crédito/débito requieren comprobante origen',
        );
      }

      const tipDocAfectado =
        cabecera.codigo_tipo_comprobante_origen ??
        (normalizarCodigoSunat(cabecera.serie_comprobante_origen).startsWith('F')
          ? '01'
          : '03');
      const numDocfectado = `${normalizarCodigoSunat(cabecera.serie_comprobante_origen)}-${this.parseCorrelativo(cabecera.numero_comprobante_origen)}`;
      const codMotivo = cabecera.codigo_motivo_nota ?? '01';

      payload.tipDocAfectado = tipDocAfectado;
      payload.numDocfectado = numDocfectado;
      payload.codMotivo = codMotivo;
      payload.desMotivo = this.formatDesMotivo(
        cabecera.nombre_motivo_nota,
        codMotivo,
      );
    }

    if (cabecera.observaciones) {
      payload.observacion = cabecera.observaciones;
    }

    return payload;
  }

  /**
   * Resumen diario SUNAT (boletas y notas de crédito de familia B).
   */
  mapComprobantesToSummaryPayload(
    items: Array<{
      codigo_tipo_comprobante?: string | null;
      serie: string;
      numero: string;
      nombre_tipo_documento_cliente?: string | null;
      documento_cliente?: string | null;
      total_importe?: number | null;
      valor_venta?: number | null;
      igv?: number | null;
      exonerado?: number | null;
      codigo_moneda?: string | null;
      codigo_tipo_comprobante_origen?: string | null;
      serie_comprobante_origen?: string | null;
      numero_comprobante_origen?: string | null;
    }>,
    empresa: EmpresaEmisora,
    fecha: string,
    correlativo: string,
  ): FacturacionApisperuPayload {
    if (!items.length) {
      throw new BadRequestException(
        'No hay boletas ni notas para el resumen diario de la fecha indicada',
      );
    }

    const moneda = normalizarCodigoSunat(items[0]?.codigo_moneda ?? 'PEN');
    const fechaFmt = this.formatFechaEmision(fecha);

    return {
      fecGeneracion: fechaFmt,
      fecResumen: fechaFmt,
      correlativo: correlativoSunat(correlativo).padStart(3, '0'),
      moneda,
      company: this.mapEmpresa(empresa),
      details: items.map((item) => this.mapSummaryDetail(item)),
    };
  }

  /**
   * Comunicación de baja (voided) para facturas y notas relacionadas a factura.
   * Las boletas (03) no usan este canal: corresponden a nota de crédito / resumen.
   */
  mapComprobanteToVoidedPayload(
    comprobante: ComprobanteCompletoResult,
    empresa: EmpresaEmisora,
    motivoBaja: string,
  ): FacturacionApisperuPayload {
    const cabecera = comprobante.registro;

    if (!cabecera) {
      throw new BadRequestException('Comprobante inválido');
    }

    const tipoDoc = normalizarCodigoSunat(cabecera.codigo_tipo_comprobante);

    if (!tipoDoc || !['01', '07', '08'].includes(tipoDoc)) {
      throw new BadRequestException(
        'La comunicación de baja solo aplica a facturas y notas asociadas. Para boletas use una nota de crédito.',
      );
    }

    const fechaEmision = this.formatFechaEmision(cabecera.fecha);
    const hoy = new Date().toISOString().slice(0, 10);

    return {
      correlativo: String(cabecera.id).padStart(5, '0'),
      fecGeneracion: fechaEmision,
      fecComunicacion: `${hoy}T00:00:00-05:00`,
      company: this.mapEmpresa(empresa),
      details: [
        {
          tipoDoc,
          serie: normalizarCodigoSunat(cabecera.serie),
          correlativo: this.parseCorrelativo(cabecera.numero),
          desMotivoBaja: motivoBaja.trim(),
        },
      ],
    };
  }

  private mapSummaryDetail(item: {
    codigo_tipo_comprobante?: string | null;
    serie: string;
    numero: string;
    nombre_tipo_documento_cliente?: string | null;
    documento_cliente?: string | null;
    total_importe?: number | null;
    valor_venta?: number | null;
    igv?: number | null;
    exonerado?: number | null;
    codigo_tipo_comprobante_origen?: string | null;
    serie_comprobante_origen?: string | null;
    numero_comprobante_origen?: string | null;
  }): Record<string, unknown> {
    const tipoDoc = normalizarCodigoSunat(item.codigo_tipo_comprobante ?? '03');
    const correlativo = this.parseCorrelativo(item.numero);
    const igv = this.round(Number(item.igv ?? 0), 2);
    const valorVenta = this.round(Number(item.valor_venta ?? 0), 2);
    const exonerado = this.round(Number(item.exonerado ?? 0), 2);
    const mtoOperGravadas = igv > 0 ? valorVenta : 0;
    const mtoOperExoneradas =
      exonerado > 0 ? exonerado : igv === 0 ? valorVenta : 0;
    const clienteNro = normalizarDocumentoSunat(item.documento_cliente) || '00000000';

    const detail: Record<string, unknown> = {
      tipoDoc,
      serieNro: `${normalizarCodigoSunat(item.serie)}-${correlativo}`,
      estado: '1',
      clienteTipo: this.mapTipoDocumentoCliente(
        item.nombre_tipo_documento_cliente,
        clienteNro,
      ),
      clienteNro,
      total: this.round(Number(item.total_importe ?? valorVenta + igv), 2),
      mtoOperGravadas,
      mtoOperExoneradas,
      mtoOperInafectas: 0,
      mtoIGV: igv,
    };

    if (
      (tipoDoc === '07' || tipoDoc === '08') &&
      item.serie_comprobante_origen &&
      item.numero_comprobante_origen
    ) {
      detail.docReferencia = {
        tipoDoc:
          item.codigo_tipo_comprobante_origen ??
          (normalizarCodigoSunat(item.serie_comprobante_origen).startsWith('F')
            ? '01'
            : '03'),
        nroDoc: `${normalizarCodigoSunat(item.serie_comprobante_origen)}-${this.parseCorrelativo(item.numero_comprobante_origen)}`,
      };
    }

    return detail;
  }

  private mapFormaPago(
    cabecera: NonNullable<ComprobanteCompletoResult['registro']>,
    cuotas: NonNullable<ComprobanteCompletoResult['cuotas']>,
    tipoMoneda: string,
    totalVenta: number,
  ): Record<string, unknown> {
    const diasCredito = Number(cabecera.dias_credito ?? 0);
    const numeroCuotasCondicion = Number(cabecera.numero_cuotas ?? 0);
    const esCredito =
      cuotas.length > 0 || diasCredito > 0 || numeroCuotasCondicion > 1;

    if (!esCredito) {
      return {
        moneda: tipoMoneda,
        tipo: 'Contado',
      };
    }

    const cuotasPayload =
      cuotas.length > 0
        ? cuotas.map((cuota) => ({
            moneda: tipoMoneda,
            monto: this.round(Number(cuota.monto), 2),
            fechaPago: this.formatFechaPago(cuota.fecha_vencimiento),
          }))
        : [
            {
              moneda: tipoMoneda,
              monto: this.round(totalVenta, 2),
              fechaPago: this.formatFechaPago(
                cabecera.fecha_vencimiento ?? cabecera.fecha,
              ),
            },
          ];

    return {
      moneda: tipoMoneda,
      tipo: 'Credito',
      cuotas: cuotasPayload,
    };
  }

  private formatFechaPago(fecha?: string | null) {
    if (!fecha) {
      return new Date().toISOString().slice(0, 10);
    }
    const civil = fechaCivilSunat(fecha);
    if (!civil) throw new BadRequestException('Revisa la fecha de vencimiento de la cuota: no es una fecha válida.');
    return civil;
  }

  private formatDesMotivo(nombre?: string | null, codigo?: string | null) {
    if (nombre?.trim()) {
      return nombre.trim().replace(/_/g, ' ');
    }

    return codigo ? `Motivo ${codigo}` : 'ANULACION DE LA OPERACION';
  }

  private mapDetalle(
    detalle: ComprobanteDetalleRegistro,
    item: number,
  ): Record<string, unknown> {
    const afectacion = detalle.codigo_afectacion_igv ?? '10';
    const tipAfeIgv = Number.parseInt(afectacion, 10);
    const cantidad = Number(detalle.cantidad);
    if (!Number.isFinite(cantidad) || cantidad <= 0) throw new BadRequestException(`La línea ${item} debe tener una cantidad válida mayor a cero.`);
    const valorVenta = Number(detalle.valor_venta);
    const igv = Number(detalle.impuesto ?? 0);
    const importe = Number(detalle.importe);
    const mtoValorUnitario =
      cantidad > 0 ? this.round(valorVenta / cantidad, 6) : 0;
    const mtoPrecioUnitario =
      cantidad > 0 ? this.round(importe / cantidad, 6) : 0;

    return {
      codProducto: detalle.codigo_producto ?? String(detalle.id_producto),
      unidad: this.mapUnidad(detalle.nombre_unidad_medida),
      descripcion:
        detalle.descripcion?.trim() ||
        detalle.nombre_producto ||
        `Producto ${detalle.id_producto}`,
      cantidad,
      mtoValorUnitario,
      mtoValorVenta: valorVenta,
      mtoBaseIgv: tipAfeIgv === 10 ? valorVenta : 0,
      porcentajeIgv: Number(detalle.porcentaje_igv ?? 18),
      igv,
      tipAfeIgv,
      totalImpuestos: igv,
      mtoPrecioUnitario,
      item,
    };
  }

  private calcularTotales(
    detalles: ComprobanteDetalleRegistro[],
    cabecera: NonNullable<ComprobanteCompletoResult['registro']>,
    usarTotalesCabecera = true,
  ) {
    let mtoOperGravadas = 0;
    let mtoOperExoneradas = 0;
    let mtoOperInafectas = 0;
    let mtoIGV = 0;
    let importeTotal = 0;

    for (const detalle of detalles) {
      const valor = Number(detalle.valor_venta);
      const afectacion = detalle.codigo_afectacion_igv ?? '10';
      importeTotal += Number(detalle.importe ?? 0);

      if (afectacion === '10') {
        mtoOperGravadas += valor;
        mtoIGV += Number(detalle.impuesto ?? 0);
      } else if (afectacion === '20') {
        mtoOperExoneradas += valor;
      } else if (afectacion === '30') {
        mtoOperInafectas += valor;
      }
    }

    const sumaValorVenta =
      mtoOperGravadas + mtoOperExoneradas + mtoOperInafectas;
    const valorVenta = this.round(
      usarTotalesCabecera ? (cabecera.valor_venta ?? sumaValorVenta) : sumaValorVenta,
      2,
    );
    const totalImpuestos = this.round(
      usarTotalesCabecera ? (cabecera.igv ?? mtoIGV) : mtoIGV,
      2,
    );
    const subTotal = this.round(
      usarTotalesCabecera
        ? (cabecera.sub_total ?? valorVenta + totalImpuestos)
        : valorVenta + totalImpuestos,
      2,
    );
    const mtoImpVenta = this.round(
      usarTotalesCabecera ? (cabecera.total_importe ?? subTotal) : importeTotal,
      2,
    );

    return {
      mtoOperGravadas: this.round(mtoOperGravadas, 2),
      mtoOperExoneradas: this.round(mtoOperExoneradas, 2),
      mtoOperInafectas: this.round(mtoOperInafectas, 2),
      mtoIGV: totalImpuestos,
      valorVenta,
      totalImpuestos,
      subTotal,
      mtoImpVenta,
    };
  }

  private mapCliente(cliente: ClienteReceptor, ubigeo: string) {
    const numDoc = normalizarDocumentoSunat(cliente.numero_documento);

    if (!numDoc) {
      throw new BadRequestException('El cliente no tiene número de documento');
    }

    const rznSocial =
      cliente.razon_social?.trim() ||
      [cliente.nombres, cliente.apellido_paterno, cliente.apellido_materno]
        .filter(Boolean)
        .join(' ')
        .trim() ||
      'Cliente';

    return {
      ...receptorSunat(cliente.nombre_tipo_documento, numDoc),
      rznSocial,
      address: {
        direccion: cliente.direccion?.trim() || undefined,
        provincia: normalizarCodigoSunat(cliente.nombre_provincia) || undefined,
        departamento: normalizarCodigoSunat(cliente.nombre_departamento) || undefined,
        distrito: normalizarCodigoSunat(cliente.nombre_distrito) || undefined,
        ubigueo: ubigeo.trim() || undefined,
      },
    };
  }

  private mapEmpresa(empresa: EmpresaEmisora) {
    if (!/^\d{6}$/.test(empresa.codigo_ubigeo?.trim() ?? '') || !empresa.direccion?.trim()) {
      throw new BadRequestException('Registra la dirección y el distrito fiscal de la empresa en Configuración → Empresa antes de emitir.');
    }
    return {
      ruc: rucSunat(empresa.ruc),
      razonSocial: empresa.razon_social?.trim() || empresa.nombre_comercial?.trim() || '',
      nombreComercial: empresa.nombre_comercial?.trim() || empresa.razon_social?.trim() || '',
      address: {
        direccion: empresa.direccion?.trim() || 'S/N',
        provincia: normalizarCodigoSunat(empresa.nombre_provincia),
        departamento: normalizarCodigoSunat(empresa.nombre_departamento),
        distrito: normalizarCodigoSunat(empresa.nombre_distrito),
        ubigueo: empresa.codigo_ubigeo!.trim(),
      },
    };
  }

  private mapTipoDocumentoCliente(tipoDocumento?: string | null, numDoc?: string): string {
    return receptorSunat(tipoDocumento, numDoc).tipoDoc;
  }

  private mapUnidad(nombreUnidad?: string | null) {
    const unidad = (nombreUnidad ?? 'NIU').trim().toUpperCase();
    return unidad.length >= 2 && unidad.length <= 4 ? unidad : 'NIU';
  }

  private parseCorrelativo(numero: string): string {
    return correlativoSunat(numero);
  }

  private formatFechaEmision(fecha: string | null | undefined): string {
    return fechaHoraSunat(fecha);
  }

  private round(value: number, decimals: number) {
    if (!Number.isFinite(value)) throw new BadRequestException('El comprobante contiene un importe inválido. Revisa los montos antes de enviar.');
    const factor = 10 ** decimals;
    return Math.round(value * factor) / factor;
  }
}
