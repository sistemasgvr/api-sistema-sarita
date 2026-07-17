import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import type {
  ComprobanteCatalogosPos,
  ComprobanteCompletoResult,
  ComprobanteResumenDiarioItem,
  ListaOpcionBasica,
  ResumenDiarioCompletoResult,
  SiguienteCorrelativoResumenResult,
} from '../interfaces/comprobante.interface';
import {
  ComprobanteCuotaDto,
  ComprobanteDetalleDto,
  CreateComprobantesDto,
  FiltroComprobantesDto,
  FiltroResumenDiarioDto,
  RegistrarRespuestaSunatDto,
  SiguienteNumeroQueryDto,
  UpdateComprobantesDto,
} from '../dto/comprobantes.dto';

export interface SiguienteNumeroResult {
  serie: string;
  id_tipo_comprobante: number;
  ultimo_numero: string | null;
  numero: string;
  error?: string;
}

function mapDetallesToJson(detalles: ComprobanteDetalleDto[]) {
  return JSON.stringify(
    detalles.map((d) => ({
      id_producto: d.idProducto,
      cantidad: d.cantidad,
      precio_unitario: d.precioUnitario,
      descuento: d.descuento ?? 0,
      porcentaje_igv: d.porcentajeIgv ?? 18,
      id_afectacion_igv: d.idAfectacionIgv ?? null,
      descripcion: d.descripcion ?? null,
      id_unidad_medida: d.idUnidadMedida ?? null,
      item: d.item ?? null,
      id_balon: d.idBalon ?? null,
      capacidad_cilindro: d.capacidadCilindro ?? null,
      id_estado_cilindro: d.idEstadoCilindro ?? null,
    })),
  );
}

function mapCuotasToJson(cuotas?: ComprobanteCuotaDto[]) {
  if (!cuotas?.length) return null;

  return JSON.stringify(
    cuotas.map((c) => ({
      numero_cuota: c.numeroCuota,
      fecha_vencimiento: c.fechaVencimiento,
      monto: c.monto,
      monto_pagado: c.montoPagado ?? 0,
      id_estado: c.idEstado ?? null,
    })),
  );
}

interface EmpresaEmisoraRow {
  id: number;
  ruc: string;
  razon_social: string | null;
  nombre_comercial: string | null;
  direccion: string | null;
}

@Injectable()
export class ComprobantesModel {
  constructor(
    private readonly db: DatabaseService,
    private readonly configService: ConfigService,
  ) {}

  listar(filtros: FiltroComprobantesDto) {
    return this.db.callFunctionJson<AuthListResult>('ven_listar_comprobantes', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoComprobante ?? null,
      filtros.idCliente ?? null,
      filtros.idEstado ?? null,
      filtros.idEstadoSunat ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.serie ?? null,
    ]);
  }

  obtenerCompleto(id: number) {
    return this.db.callFunctionJson<ComprobanteCompletoResult>(
      'ven_obtener_comprobante',
      [id],
    );
  }

  obtenerPorId(id: number) {
    return this.obtenerCompleto(id);
  }

  async listarOpcionesPorLista(nombreLista: string) {
    const result = await this.db.query<ListaOpcionBasica>(
      `SELECT lo.id, lo.nombre, lo.descripcion
       FROM gen_lista_opciones lo
       INNER JOIN gen_lista l ON lo.id_lista = l.id
       WHERE l.nombre = $1 AND lo.estado = 1
       ORDER BY lo.nombre`,
      [nombreLista],
    );

    return result.rows;
  }

  async obtenerCatalogosPos(): Promise<ComprobanteCatalogosPos> {
    const [
      tiposComprobante,
      afectacionesIgv,
      monedas,
      mediosPago,
      tiposOperacionSunat,
      estadosSunat,
      motivosNotaCredito,
    ] = await Promise.all([
      this.listarOpcionesPorLista('TipoComprobante'),
      this.listarOpcionesPorLista('AfectacionIgv'),
      this.listarOpcionesPorLista('Moneda'),
      this.listarOpcionesPorLista('MedioPago'),
      this.listarOpcionesPorLista('TipoOperacionSunat'),
      this.listarOpcionesPorLista('EstadoSunat'),
      this.listarOpcionesPorLista('MotivoNotaCredito'),
    ]);

    return {
      tiposComprobante,
      afectacionesIgv,
      monedas,
      mediosPago,
      tiposOperacionSunat,
      estadosSunat,
      motivosNotaCredito,
    };
  }

  async listarParaResumenDiario(
    fecha: string,
    idsComprobante?: number[],
  ): Promise<ComprobanteResumenDiarioItem[]> {
    const params: unknown[] = [fecha];
    let idsFilter = '';

    if (idsComprobante?.length) {
      params.push(idsComprobante);
      idsFilter = ` AND c.id = ANY($${params.length}::int[])`;
    }

    const result = await this.db.query<ComprobanteResumenDiarioItem>(
      `SELECT
         c.id,
         tc.descripcion AS codigo_tipo_comprobante,
         tc.nombre AS nombre_tipo_comprobante,
         c.serie,
         c.numero,
         c.fecha::text AS fecha,
         c.id_cliente,
         COALESCE(
           cl.razon_social,
           TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
         ) AS nombre_cliente,
         cl.numero_documento AS documento_cliente,
         td.nombre AS nombre_tipo_documento_cliente,
         es.nombre AS nombre_estado_sunat,
         mo.descripcion AS codigo_moneda,
         c.valor_venta,
         c.igv,
         c.exonerado,
         c.total_importe,
         tc_origen.descripcion AS codigo_tipo_comprobante_origen,
         co.serie AS serie_comprobante_origen,
         co.numero AS numero_comprobante_origen
       FROM ven_comprobante c
       INNER JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
       LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
       LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
       LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
       LEFT JOIN gen_lista_opciones td ON cl.id_tipo_documento = td.id
       LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
       LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
       WHERE c.estado = 1
         AND c.fecha::date = $1::date
         AND (
           tc.descripcion = '03'
           OR (tc.descripcion IN ('07', '08') AND UPPER(c.serie) LIKE 'B%')
         )
         AND COALESCE(es.nombre, 'PENDIENTE') IN ('PENDIENTE', 'ACEPTADO')
         ${idsFilter}
       ORDER BY c.serie, c.numero`,
      params,
    );

    return result.rows;
  }

  async resolverIdEstadoSunat(nombreEstado: string) {
    const result = await this.db.query<{ id: number }>(
      `SELECT lo.id
       FROM gen_lista_opciones lo
       INNER JOIN gen_lista l ON lo.id_lista = l.id
       WHERE l.nombre = 'EstadoSunat'
         AND lo.nombre = $1
         AND lo.estado = 1
       LIMIT 1`,
      [nombreEstado],
    );

    return result.rows[0]?.id ?? null;
  }

  async obtenerCodigoUbigeoDistrito(idDistrito: number) {
    const result = await this.db.query<{ codigo_ubigeo: string | null }>(
      `SELECT codigo_ubigeo FROM gen_distrito WHERE id = $1 LIMIT 1`,
      [idDistrito],
    );

    return result.rows[0]?.codigo_ubigeo ?? '150101';
  }

  async obtenerEmpresaEmisora(): Promise<EmpresaEmisoraRow | null> {
    const defaultRuc =
      this.configService.get<string>('facturacion.defaultRuc') ?? null;

    if (defaultRuc) {
      const byRuc = await this.db.query<EmpresaEmisoraRow>(
        `SELECT id, ruc, razon_social, nombre_comercial, direccion
         FROM gen_empresa
         WHERE estado = 1 AND ruc = $1
         LIMIT 1`,
        [defaultRuc],
      );

      if (byRuc.rows[0]) return byRuc.rows[0];
    }

    const result = await this.db.query<EmpresaEmisoraRow>(
      `SELECT id, ruc, razon_social, nombre_comercial, direccion
       FROM gen_empresa
       WHERE estado = 1
       ORDER BY id
       LIMIT 1`,
    );

    return result.rows[0] ?? null;
  }

  obtenerSiguienteNumero(query: SiguienteNumeroQueryDto) {
    return this.db.callFunctionJson<SiguienteNumeroResult>('ven_obtener_siguiente_numero', [
      query.idTipoComprobante,
      query.serie,
    ]);
  }

  crear(dto: CreateComprobantesDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_crear_comprobante', [
      dto.idTipoComprobante,
      dto.serie,
      dto.numero ?? null,
      dto.fecha,
      dto.idCliente,
      mapDetallesToJson(dto.detalles),
      dto.idTipoOperacionSunat ?? null,
      dto.idComprobanteOrigen ?? null,
      dto.idMotivoNota ?? null,
      dto.idTipoMovimiento ?? null,
      dto.idTipoVenta ?? null,
      dto.fechaVencimiento ?? null,
      dto.tipoCambio ?? 3.5,
      dto.idSucursal ?? null,
      dto.idAlmacen ?? null,
      dto.idCondicionPago ?? null,
      dto.idMoneda ?? null,
      dto.idMedioPago ?? null,
      dto.glosa ?? null,
      dto.observaciones ?? null,
      dto.periodoContable ?? null,
      dto.operacion ?? null,
      dto.idEstado ?? null,
      mapCuotasToJson(dto.cuotas),
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateComprobantesDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_actualizar_comprobante', [
      id,
      dto.fecha ?? null,
      dto.idCliente ?? null,
      dto.detalles ? mapDetallesToJson(dto.detalles) : null,
      dto.idTipoOperacionSunat ?? null,
      dto.idComprobanteOrigen ?? null,
      dto.idMotivoNota ?? null,
      dto.idTipoMovimiento ?? null,
      dto.idTipoVenta ?? null,
      dto.fechaVencimiento ?? null,
      dto.tipoCambio ?? null,
      dto.idSucursal ?? null,
      dto.idAlmacen ?? null,
      dto.idCondicionPago ?? null,
      dto.idMoneda ?? null,
      dto.idMedioPago ?? null,
      dto.glosa ?? null,
      dto.observaciones ?? null,
      dto.periodoContable ?? null,
      dto.operacion ?? null,
      dto.idEstado ?? null,
      dto.cuotas !== undefined ? mapCuotasToJson(dto.cuotas) : null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('ven_eliminar_comprobante', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  registrarRespuestaSunat(id: number, dto: RegistrarRespuestaSunatDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_registrar_respuesta_sunat', [
      id,
      dto.idEstadoSunat ?? null,
      dto.ticketSunat ?? null,
      dto.hashDocumento ?? null,
      dto.xmlFirmado ?? null,
      dto.cdrRespuesta ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  listarResumenDiario(filtros: FiltroResumenDiarioDto) {
    return this.db.callFunctionJson<AuthListResult>('ven_listar_resumen_diario', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idEstadoSunat ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerResumenDiario(id: number) {
    return this.db.callFunctionJson<ResumenDiarioCompletoResult>(
      'ven_obtener_resumen_diario',
      [id],
    );
  }

  obtenerSiguienteCorrelativoResumen(fecha: string) {
    return this.db.callFunctionJson<SiguienteCorrelativoResumenResult>(
      'ven_obtener_siguiente_correlativo_resumen',
      [fecha],
    );
  }

  crearResumenDiario(params: {
    fecha: string;
    correlativo: string;
    ticketSunat?: string | null;
    idEstadoSunat?: number | null;
    cdrRespuesta?: string | null;
    moneda?: string | null;
    cantidadDocs: number;
    totalImporte: number;
    totalIgv: number;
    totalValorVenta: number;
    idsComprobante: number[];
    idUsuarioAuditoria?: number;
  }) {
    return this.db.callFunctionJson<ResumenDiarioCompletoResult>(
      'ven_crear_resumen_diario',
      [
        params.fecha,
        params.correlativo,
        params.ticketSunat ?? null,
        params.idEstadoSunat ?? null,
        params.cdrRespuesta ?? null,
        params.moneda ?? 'PEN',
        params.cantidadDocs,
        params.totalImporte,
        params.totalIgv,
        params.totalValorVenta,
        JSON.stringify(params.idsComprobante),
        params.idUsuarioAuditoria ?? null,
      ],
    );
  }

  registrarRespuestaResumenDiario(
    id: number,
    dto: {
      idEstadoSunat?: number | null;
      ticketSunat?: string | null;
      cdrRespuesta?: string | null;
      idUsuarioAuditoria?: number;
    },
  ) {
    return this.db.callFunctionJson<ResumenDiarioCompletoResult>(
      'ven_registrar_respuesta_resumen_diario',
      [
        id,
        dto.idEstadoSunat ?? null,
        dto.ticketSunat ?? null,
        dto.cdrRespuesta ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }
}
