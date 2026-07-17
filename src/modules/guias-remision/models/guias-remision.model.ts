import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  AuthDeleteResult,
  AuthListResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateGuiaRemisionDto,
  FiltroGuiaRemisionDto,
  GuiaRemisionDetalleDto,
  GuiaRemisionReferenciaDto,
  SiguienteNumeroGuiaQueryDto,
  UpdateGuiaRemisionDto,
} from '../dto/guias-remision.dto';
import type {
  GuiaRemisionCatalogos,
  GuiaRemisionCompletoResult,
  ListaOpcionBasica,
  SiguienteNumeroGuiaResult,
} from '../interfaces/guia-remision.interface';

interface EmpresaEmisoraRow {
  id: number;
  ruc: string;
  razon_social: string | null;
  nombre_comercial: string | null;
  direccion: string | null;
}

function mapDetallesToJson(detalles: GuiaRemisionDetalleDto[]) {
  return JSON.stringify(
    detalles.map((d) => ({
      item: d.item ?? null,
      id_producto: d.idProducto,
      descripcion: d.descripcion ?? null,
      id_unidad_medida: d.idUnidadMedida ?? null,
      cantidad: d.cantidad,
      id_balon: d.idBalon ?? null,
      glosa: d.glosa ?? null,
    })),
  );
}

function mapReferenciasToJson(referencias?: GuiaRemisionReferenciaDto[]) {
  if (!referencias?.length) return null;

  return JSON.stringify(
    referencias.map((r) => ({
      id_tipo_comprobante: r.idTipoComprobante,
      serie: r.serie ?? null,
      numero: r.numero ?? null,
      fecha: r.fecha ?? null,
    })),
  );
}

@Injectable()
export class GuiasRemisionModel {
  constructor(
    private readonly db: DatabaseService,
    private readonly configService: ConfigService,
  ) {}

  listar(filtros: FiltroGuiaRemisionDto) {
    return this.db.callFunctionJson<AuthListResult>('gre_listar_guias_remision', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoGuia ?? null,
      filtros.idDestinatario ?? null,
      filtros.idEstado ?? null,
      filtros.idEstadoSunat ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.serie ?? null,
    ]);
  }

  obtenerCompleto(id: number) {
    return this.db.callFunctionJson<GuiaRemisionCompletoResult>(
      'gre_obtener_guia_remision',
      [id],
    );
  }

  obtenerSiguienteNumero(query: SiguienteNumeroGuiaQueryDto) {
    return this.db.callFunctionJson<SiguienteNumeroGuiaResult>(
      'gre_obtener_siguiente_numero',
      [query.serie],
    );
  }

  crear(dto: CreateGuiaRemisionDto) {
    return this.db.callFunctionJson<GuiaRemisionCompletoResult>(
      'gre_crear_guia_remision',
      [
        dto.idTipoGuiaRemision,
        dto.serie,
        dto.numero ?? null,
        dto.fecha ?? null,
        dto.fechaTraslado ?? null,
        dto.idSucursal,
        dto.idAlmacen,
        dto.idCliente ?? null,
        dto.idMotivoTraslado,
        dto.idUnidadMedida ?? null,
        dto.pesoBruto,
        dto.numeroBultos ?? null,
        dto.direccionOrigen ?? null,
        dto.idDistritoOrigen,
        dto.idDestinatario,
        dto.direccionLlegada ?? null,
        dto.idDistritoLlegada,
        dto.idModalidadTraslado,
        dto.idTransportista ?? null,
        dto.idChofer ?? null,
        dto.idVehiculo ?? null,
        dto.idResponsable ?? null,
        dto.observaciones ?? null,
        mapDetallesToJson(dto.detalles),
        mapReferenciasToJson(dto.referencias),
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateGuiaRemisionDto) {
    return this.db.callFunctionJson<GuiaRemisionCompletoResult>(
      'gre_actualizar_guia_remision',
      [
        id,
        dto.fecha ?? null,
        dto.fechaTraslado ?? null,
        dto.idSucursal ?? null,
        dto.idAlmacen ?? null,
        dto.idCliente ?? null,
        dto.idMotivoTraslado ?? null,
        dto.idUnidadMedida ?? null,
        dto.pesoBruto ?? null,
        dto.numeroBultos ?? null,
        dto.direccionOrigen ?? null,
        dto.idDistritoOrigen ?? null,
        dto.idDestinatario ?? null,
        dto.direccionLlegada ?? null,
        dto.idDistritoLlegada ?? null,
        dto.idModalidadTraslado ?? null,
        dto.idTransportista ?? null,
        dto.idChofer ?? null,
        dto.idVehiculo ?? null,
        dto.idResponsable ?? null,
        dto.observaciones ?? null,
        dto.detalles ? mapDetallesToJson(dto.detalles) : null,
        dto.referencias ? mapReferenciasToJson(dto.referencias) : null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'gre_eliminar_guia_remision',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  registrarRespuestaSunat(
    id: number,
    params: {
      ticketSunat?: string | null;
      hashDocumento?: string | null;
      xmlFirmado?: string | null;
      cdrRespuesta?: string | null;
      nombreEstadoSunat?: string | null;
      idUsuarioAuditoria?: number;
    },
  ) {
    return this.db.callFunctionJson<GuiaRemisionCompletoResult>(
      'gre_registrar_respuesta_sunat',
      [
        id,
        params.ticketSunat ?? null,
        params.hashDocumento ?? null,
        params.xmlFirmado ?? null,
        params.cdrRespuesta ?? null,
        params.nombreEstadoSunat ?? null,
        params.idUsuarioAuditoria ?? null,
      ],
    );
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

  async obtenerCatalogos(): Promise<GuiaRemisionCatalogos> {
    const [
      tiposGuia,
      modalidadesTraslado,
      motivosTraslado,
      estadosGuia,
      estadosSunat,
      unidadesMedida,
    ] = await Promise.all([
      this.listarOpcionesPorLista('TipoGuiaRemision'),
      this.listarOpcionesPorLista('ModalidadTraslado'),
      this.listarOpcionesPorLista('MotivoTraslado'),
      this.listarOpcionesPorLista('EstadoGuiaRemision'),
      this.listarOpcionesPorLista('EstadoSunat'),
      this.listarOpcionesPorLista('UnidadMedida'),
    ]);

    return {
      tiposGuia,
      modalidadesTraslado,
      motivosTraslado,
      estadosGuia,
      estadosSunat,
      unidadesMedida,
    };
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
}
