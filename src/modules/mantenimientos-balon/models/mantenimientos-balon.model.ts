import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreateMantenimientosBalonDto,
  FinalizarMantenimientosBalonDto,
  FiltroMantenimientosBalonDto,
  UpdateMantenimientosBalonDto,
} from '../dto/mantenimientos-balon.dto';

@Injectable()
export class MantenimientosBalonModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroMantenimientosBalonDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_mantenimientos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idBalon ?? null,
      filtros.idTipoMantenimiento ?? null,
      filtros.idEstado ?? null,
      filtros.esExterno ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_mantenimiento', [id]);
  }

  crear(dto: CreateMantenimientosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_mantenimiento', [
      dto.idBalon ?? null,
      dto.fechaIngreso ?? null,
      dto.idTipoMantenimiento ?? null,
      dto.fechaSalida ?? null,
      dto.descripcion ?? null,
      dto.costo ?? null,
      dto.esExterno ?? false,
      dto.idProveedor ?? null,
      dto.idEstado ?? null,
      dto.idComprobanteVenta ?? null,
      dto.idComprobanteCompra ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.vigenciaPhAnios ?? null,
      dto.idOrganoInspector ?? null,
      dto.organoInspectorNoAplica ?? null,
      dto.numeroCertificadoPh ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateMantenimientosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_mantenimiento', [
      id,
      dto.idTipoMantenimiento ?? null,
      dto.fechaIngreso ?? null,
      dto.fechaSalida ?? null,
      dto.descripcion ?? null,
      dto.costo ?? null,
      dto.esExterno ?? null,
      dto.idProveedor ?? null,
      dto.idEstado ?? null,
      dto.idComprobanteVenta ?? null,
      dto.idComprobanteCompra ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.vigenciaPhAnios ?? null,
      dto.idOrganoInspector ?? null,
      dto.organoInspectorNoAplica ?? null,
      dto.numeroCertificadoPh ?? null,
    ]);
  }

  finalizar(id: number, dto: FinalizarMantenimientosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_finalizar_mantenimiento', [
      id,
      dto.fechaSalida ?? null,
      dto.idAlmacenDestino ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
      dto.vigenciaPhAnios ?? null,
      dto.idOrganoInspector ?? null,
      dto.organoInspectorNoAplica ?? null,
      dto.numeroCertificadoPh ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_mantenimiento', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
