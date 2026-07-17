import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreatePrestamosDetalleDto,
  FiltroPrestamosDetalleDto,
  UpdatePrestamosDetalleDto,
} from '../dto/prestamos-detalle.dto';

@Injectable()
export class PrestamosDetalleModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPrestamosDetalleDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_prestamo_detalles', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idPrestamo ?? null,
      filtros.idBalon ?? null,
      filtros.idEstado ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_prestamo_detalle', [id]);
  }

  crear(dto: CreatePrestamosDetalleDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_prestamo_detalle', [
      dto.idPrestamo ?? null,
      dto.idBalon ?? null,
      dto.idProducto ?? null,
      dto.motivoEspecifico ?? null,
      dto.fechaEntregado ?? null,
      dto.fechaPrestamo ?? null,
      dto.diasPrestamo ?? null,
      dto.fechaVencimiento ?? null,
      dto.fechaDevolucion ?? null,
      dto.serieGuiaEntrega ?? null,
      dto.numeroGuiaEntrega ?? null,
      dto.serieGuiaDevolucion ?? null,
      dto.numeroGuiaDevolucion ?? null,
      dto.idEstado ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdatePrestamosDetalleDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_prestamo_detalle', [
      id,
      dto.idBalon ?? null,
      dto.idProducto ?? null,
      dto.motivoEspecifico ?? null,
      dto.fechaEntregado ?? null,
      dto.fechaPrestamo ?? null,
      dto.diasPrestamo ?? null,
      dto.fechaVencimiento ?? null,
      dto.fechaDevolucion ?? null,
      dto.serieGuiaEntrega ?? null,
      dto.numeroGuiaEntrega ?? null,
      dto.serieGuiaDevolucion ?? null,
      dto.numeroGuiaDevolucion ?? null,
      dto.idEstado ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_prestamo_detalle', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
