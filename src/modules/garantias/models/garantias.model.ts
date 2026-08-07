import { Injectable } from '@nestjs/common';
import {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateGarantiaDto,
  DevolverGarantiaDto,
  FiltroGarantiasDto,
} from '../dto/garantias.dto';

@Injectable()
export class GarantiasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroGarantiasDto) {
    return this.db.callFunctionJson<AuthListResult>('ven_listar_garantias', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idCliente ?? null,
      filtros.idPrestamo ?? null,
      filtros.idEstado ?? null,
      filtros.idAlquiler ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_obtener_garantia', [id]);
  }

  crear(dto: CreateGarantiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_crear_garantia', [
      dto.idCliente,
      dto.monto,
      dto.idComprobante ?? null,
      dto.idPrestamo ?? null,
      dto.idProducto ?? null,
      dto.ubicacion ?? null,
      dto.cantidadVenta ?? null,
      dto.idUnidadMedida ?? null,
      dto.fechaRegistro ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.idAlquiler ?? null,
    ]);
  }

  devolver(id: number, dto: DevolverGarantiaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('ven_devolver_garantia', [
      id,
      dto.monto,
      dto.idComprobante ?? null,
      dto.fecha ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }
}
