import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CreateCompraDto, UpdateCompraDto, FiltroComprasDto } from '../dto/compras.dto';

@Injectable()
export class ComprasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroComprasDto) {
    return this.db.callFunctionJson<AuthListResult>('com_listar_compras', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
      filtros.idProveedor ?? null,
      filtros.idTipoComprobante ?? null,
      filtros.idTipoRegistro ?? null,
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
      dto.idTipoRegistro ?? null,
      dto.idCategoriaGasto ?? null,
      dto.idSucursal ?? null,
      dto.idAlmacen ?? null,
      dto.idMoneda ?? null,
      dto.idCondicionPago ?? null,
      dto.subTotal ?? 0,
      dto.igv ?? 0,
      dto.totalImporte,
      dto.afectaInventario ?? false,
      dto.declararSunat ?? false,
      dto.glosa ?? null,
      JSON.stringify(dto.detalles ?? []), 
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateCompraDto) {
    return this.db.callFunctionJson<AuthSingleResult>('com_actualizar_compra', [
      id,
      dto.idTipoComprobante ?? null,
      dto.serie ?? null,
      dto.numero ?? null,
      dto.fecha ?? null,
      dto.idProveedor ?? null,
      dto.idTipoRegistro ?? null,
      dto.idCategoriaGasto ?? null,
      dto.idSucursal ?? null,
      dto.idAlmacen ?? null,
      dto.idMoneda ?? null,
      dto.idCondicionPago ?? null,
      dto.subTotal ?? null,
      dto.igv ?? null,
      dto.totalImporte ?? null,
      dto.afectaInventario ?? null,
      dto.declararSunat ?? null,
      dto.glosa ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('com_eliminar_compra', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}