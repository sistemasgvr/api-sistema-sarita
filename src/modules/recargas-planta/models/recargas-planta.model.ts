import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateRecargaPlantaDto,
  FiltroRecargasPlantaDto,
  UpdateRecargaPlantaDto,
} from '../dto/recargas-planta.dto';

@Injectable()
export class RecargasPlantaModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroRecargasPlantaDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_recargas_planta', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idProveedor ?? null,
      filtros.idAlmacen ?? null,
      filtros.idEstado ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_recarga_planta', [id]);
  }

  crear(dto: CreateRecargaPlantaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_recarga_planta', [
      dto.fechaSalida,
      dto.idProveedor ?? null,
      dto.idAlmacen ?? null,
      dto.idGuiaSalida ?? null,
      dto.serieGuiaSalida ?? null,
      dto.numeroGuiaSalida ?? null,
      dto.observacion ?? null,
      dto.confirmarSalida ?? true,
      JSON.stringify(dto.detalles ?? []),
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateRecargaPlantaDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_recarga_planta', [
      id,
      dto.fechaSalida ?? null,
      dto.idProveedor ?? null,
      dto.idAlmacen ?? null,
      dto.idGuiaRetorno ?? null,
      dto.serieGuiaIngreso ?? null,
      dto.numeroGuiaIngreso ?? null,
      dto.idComprobanteCompra ?? null,
      dto.serieFactura ?? null,
      dto.numeroFactura ?? null,
      dto.fechaLlegadaAlmacen ?? null,
      dto.lote ?? null,
      dto.fechaVencimientoLote ?? null,
      dto.fechaPruebaHidrostatica ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_recarga_planta', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
