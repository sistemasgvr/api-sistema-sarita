import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../../database/database.service';
import {
  AnularDocSalidaDto,
  ConvertirGreDto,
  CreateDocSalidaDetalleDto,
  CreateDocSalidaDto,
  CrearDesdeVentaDto,
  FiltroDocSalidaDto,
  FinalizarRecargaDto,
  GenerarRecojoDocSalidaDto,
  RegistrarDireccionEntregaDto,
  SiguienteNumeroDocSalidaQueryDto,
} from '../dto/documentos-salida.dto';
import type {
  DocSalidaEliminarDetalleResult,
  DocumentoSalidaCatalogos,
  DocumentoSalidaCompletoResult,
  DocumentoSalidaListResult,
  ListaOpcionBasica,
} from '../interfaces/documento-salida.interface';

interface EmpresaEmisoraRow {
  id: number;
  ruc: string;
  razon_social: string | null;
  nombre_comercial: string | null;
  direccion: string | null;
}

@Injectable()
export class DocumentosSalidaModel {
  constructor(
    private readonly db: DatabaseService,
    private readonly configService: ConfigService,
  ) {}

  listar(filtros: FiltroDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaListResult>('doc_listar_salidas', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoOrden ?? null,
      filtros.idEstadoCiclo ?? null,
      filtros.idSucursal ?? null,
      filtros.idAlmacen ?? null,
      filtros.idCliente ?? null,
      filtros.emitidoSunat ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.codigoTipoOrden ?? null,
    ]);
  }

  obtener(id: number) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_obtener_salida', [id]);
  }

  obtenerSiguienteNumero(query: SiguienteNumeroDocSalidaQueryDto) {
    return this.db.callFunctionJson<string>('doc_obtener_siguiente_numero', [
      query.idSucursal,
      query.fecha ?? null,
    ]);
  }

  crear(dto: CreateDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_crear_salida', [
      dto.codigoTipoOrden,
      dto.idSucursal,
      dto.idAlmacen,
      dto.idVenta ?? null,
      dto.idCliente ?? null,
      dto.idDestinatario ?? null,
      dto.idProveedor ?? null,
      dto.idDocSalidaOrigen ?? null,
      dto.fecha ?? null,
      dto.fechaTraslado ?? null,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  crearDesdeVenta(dto: CrearDesdeVentaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_crear_desde_venta', [
      dto.idVenta,
      dto.idDestinatario ?? null,
      dto.fechaTraslado ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  agregarDetalle(idDocSalida: number, dto: CreateDocSalidaDetalleDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_crear_salida_detalle', [
      idDocSalida,
      dto.idProducto ?? null,
      dto.idBalon ?? null,
      dto.cantidad,
      dto.descripcion ?? null,
      dto.idUnidadMedida ?? null,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarDetalle(idDetalle: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<DocSalidaEliminarDetalleResult>(
      'doc_eliminar_salida_detalle',
      [idDetalle, idUsuarioAuditoria ?? null],
    );
  }

  generar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_generar_salida', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  convertirAGre(id: number, dto: ConvertirGreDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_convertir_a_gre', [
      id,
      dto.idTipoGuiaRemision ?? null,
      dto.serie,
      dto.idMotivoTraslado ?? null,
      dto.idModalidadTraslado ?? null,
      dto.idTransportista ?? null,
      dto.idChofer ?? null,
      dto.idVehiculo ?? null,
      dto.idUnidadMedida ?? null,
      dto.pesoBruto ?? null,
      dto.numeroBultos ?? null,
      dto.direccionOrigen ?? null,
      dto.idDistritoOrigen ?? null,
      dto.direccionLlegada ?? null,
      dto.idDistritoLlegada ?? null,
      dto.fechaTraslado ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  registrarDireccionEntrega(id: number, dto: RegistrarDireccionEntregaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_registrar_direccion_entrega', [
      id,
      dto.direccionEntrega ?? null,
      dto.referenciaEntrega ?? null,
      dto.latitud ?? null,
      dto.longitud ?? null,
      dto.idDistritoEntrega ?? null,
      dto.idDireccionCliente ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  anular(id: number, dto: AnularDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_anular_salida', [
      id,
      dto.motivo ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  finalizarRecarga(id: number, dto: FinalizarRecargaDto) {
    return this.db.callFunctionJson<{ error: string | null; registro: { id_recarga_planta: number } | null }>(
      'bal_finalizar_recarga_planta',
      [
        id,
        dto.idComprobanteCompra ?? null,
        dto.fechaLlegadaAlmacen,
        dto.idAlmacen,
        dto.idProveedor ?? null,
        dto.guardarBalonesAlmacen ?? false,
        dto.lote ?? null,
        dto.fechaVencimientoLote ?? null,
        dto.fechaPruebaHidrostatica ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  generarRecojo(id: number, dto: GenerarRecojoDocSalidaDto) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>(
      'bal_generar_recojo_recarga_planta',
      [
        id,
        dto.fechaProgramada ?? null,
        dto.idUsuarioResponsable ?? null,
        dto.observacion ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  registrarRespuestaSunat(
    id: number,
    params: {
      codigoEstadoSunat: string;
      ticketSunat?: string | null;
      hashDocumento?: string | null;
      xmlFirmado?: string | null;
      cdrRespuesta?: string | null;
      idUsuarioAuditoria?: number;
    },
  ) {
    return this.db.callFunctionJson<DocumentoSalidaCompletoResult>('doc_registrar_respuesta_sunat', [
      id,
      params.codigoEstadoSunat,
      params.ticketSunat ?? null,
      params.hashDocumento ?? null,
      params.xmlFirmado ?? null,
      params.cdrRespuesta ?? null,
      params.idUsuarioAuditoria ?? null,
    ]);
  }

  async listarOpcionesPorLista(nombreLista: string) {
    const result = await this.db.query<ListaOpcionBasica>(
      `SELECT lo.id, lo.nombre, lo.descripcion
       FROM gen_lista_opciones lo
       INNER JOIN gen_lista l ON lo.id_lista = l.id
       WHERE l.nombre = $1 AND lo.estado = 1
       ORDER BY lo.id`,
      [nombreLista],
    );

    return result.rows;
  }

  async obtenerCatalogos(): Promise<DocumentoSalidaCatalogos> {
    const [
      tiposOrden,
      estadosCiclo,
      tiposGuia,
      modalidadesTraslado,
      motivosTraslado,
      estadosSunat,
      unidadesMedida,
    ] = await Promise.all([
      this.listarOpcionesPorLista('TipoOrdenSalida'),
      this.listarOpcionesPorLista('EstadoCicloSalida'),
      this.listarOpcionesPorLista('TipoGuiaRemision'),
      this.listarOpcionesPorLista('ModalidadTraslado'),
      this.listarOpcionesPorLista('MotivoTraslado'),
      this.listarOpcionesPorLista('EstadoSunat'),
      this.listarOpcionesPorLista('UnidadMedida'),
    ]);

    return {
      tiposOrden,
      estadosCiclo,
      tiposGuia,
      modalidadesTraslado,
      motivosTraslado,
      estadosSunat,
      unidadesMedida,
    };
  }

  async obtenerEmpresaEmisora(preferredRuc?: string | null): Promise<EmpresaEmisoraRow | null> {
    const defaultRuc = (
      preferredRuc ||
      this.configService.get<string>('facturacion.defaultRuc') ||
      ''
    ).trim();

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
}
