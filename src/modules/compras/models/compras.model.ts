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
  CreateCompraDetalleDto,
  CreateCompraDetalleLineaDto,
  CreateCompraDto,
  FiltroComprasDto,
} from '../dto/compras.dto';

function mapDetallesToJson(detalles: CreateCompraDetalleDto[]) {
  return JSON.stringify(
    detalles.map((d) => ({
      id_producto: d.idProducto,
      cantidad: d.cantidad,
      precio_unitario: d.precioUnitario ?? 0,
      id_clasificacion_gasto: d.idClasificacionGasto ?? null,
      descripcion: d.descripcion ?? null,
      id_unidad_medida: d.idUnidadMedida ?? null,
      id_almacen: d.idAlmacen ?? null,
    })),
  );
}

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
      filtros.idTipoRegistro ?? null,
      filtros.idCategoriaGasto ?? null,
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
      mapDetallesToJson(dto.detalles ?? []),
      dto.idComprobanteReferencia ?? null,
      dto.idRecargaPlanta ?? null,
      dto.idTipoRegistro ?? null,
      dto.idCategoriaGasto ?? null,
      dto.idSucursal ?? null,
      dto.idMoneda ?? null,
      dto.idCondicionPago ?? null,
      dto.declararSunat ?? false,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.guardarBalonesAlmacen ?? false,
      dto.fechaLlegadaAlmacen ?? null,
      dto.lote ?? null,
      dto.fechaVencimientoLote ?? null,
      dto.fechaPruebaHidrostatica ?? null,
      dto.idGuiaRetorno ?? null,
      dto.serieGuiaIngreso ?? null,
      dto.numeroGuiaIngreso ?? null,
      dto.fechaVencimiento ?? null,
      dto.cuotas?.length
        ? JSON.stringify(
            dto.cuotas.map((c) => ({
              fechaPago: c.fechaPago,
              monto: c.monto ?? null,
            })),
          )
        : null,
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
        dto.fechaVencimiento ?? null,
        dto.cuotas?.length
          ? JSON.stringify(
              dto.cuotas.map((c) => ({
                fechaPago: c.fechaPago,
                monto: c.monto ?? null,
              })),
            )
          : null,
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
