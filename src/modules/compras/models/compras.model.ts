import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  ActualizarCompraCabeceraDto,
  ActualizarCompraDetalleDto,
  CreateCompraDetalleLineaDto,
  CreateCompraDto,
  FiltroComprasDto,
} from '../dto/compras.dto';

@Injectable()
export class ComprasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroComprasDto) {
    return this.db.callFunctionJson<AuthListResult>('com_listar_compras', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idProveedor ?? null,
      filtros.idAlmacen ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.estado ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('com_obtener_compra', [
      id,
    ]);
  }

  crear(dto: CreateCompraDto) {
    return this.db.callFunctionJson<AuthSingleResult>('com_crear_compra', [
      dto.idTipoComprobante ?? null,
      dto.serie ?? null,
      dto.numero ?? null,
      dto.fecha,
      dto.idProveedor ?? null,
      dto.idAlmacen ?? null,
      JSON.stringify(dto.detalles ?? []),
      dto.idComprobanteReferencia ?? null,
      dto.idTipoRegistro ?? null,
      dto.idCategoriaGasto ?? null,
      dto.idSucursal ?? null,
      dto.idMoneda ?? null,
      dto.idCondicionPago ?? null,
      dto.declararSunat ?? false,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idRecargaPlanta ?? null,
      dto.guardarBalonesAlmacen ?? false,
    ]);
  }

  actualizarCabecera(id: number, dto: ActualizarCompraCabeceraDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'com_actualizar_compra_cabecera',
      [
        id,
        dto.glosa ?? null,
        dto.idCondicionPago ?? null,
        dto.idCategoriaGasto ?? null,
        dto.declararSunat ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  crearDetalle(idComprobante: number, dto: CreateCompraDetalleLineaDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'com_crear_compra_detalle',
      [
        idComprobante,
        dto.idProducto,
        dto.cantidad,
        dto.precioUnitario ?? 0,
        dto.idClasificacionGasto ?? null,
        dto.descripcion ?? null,
        dto.idUnidadMedida ?? null,
        dto.idAlmacen ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizarDetalle(idDetalle: number, dto: ActualizarCompraDetalleDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'com_actualizar_compra_detalle',
      [
        idDetalle,
        dto.cantidad ?? null,
        dto.precioUnitario ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminarDetalle(idDetalle: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'com_eliminar_compra_detalle',
      [idDetalle, idUsuarioAuditoria ?? null],
    );
  }

  anular(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('com_anular_compra', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
