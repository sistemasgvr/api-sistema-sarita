import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateTrabajadorDto,
  FiltroTrabajadorDto,
  UpdateTrabajadorDto,
} from '../dto/trabajadores.dto';

@Injectable()
export class TrabajadoresModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroTrabajadorDto) {
    return this.db.callFunctionJson<AuthListResult>('tra_listar_trabajadores', [
      filtros.estado ?? null,
      filtros.buscar ?? '',
      filtros.idArea ?? null,
      filtros.idCargo ?? null,
      filtros.limite ?? 10,
      filtros.offset ?? 0,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'tra_obtener_trabajador',
      [id],
    );
  }

  crear(dto: CreateTrabajadorDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'tra_crear_trabajador',
      [
        dto.nombres,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.idTipoDocumento ?? null,
        dto.numeroDocumento ?? null,
        dto.direccion ?? null,
        dto.referencia ?? null,
        dto.latitud ?? null,
        dto.longitud ?? null,
        dto.idPais ?? null,
        dto.idDepartamento ?? null,
        dto.idProvincia ?? null,
        dto.idDistrito ?? null,
        dto.fechaNacimiento ?? null,
        dto.fechaInicio ?? null,
        dto.fechaCese ?? null,
        dto.idArea ?? null,
        dto.idCargo ?? null,
        dto.idUsuarioVinculo ?? null,
        dto.idChofer ?? null,
        dto.idUsuarioAuditoria ?? null,
        dto.correo ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateTrabajadorDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'tra_actualizar_trabajador',
      [
        id,
        dto.nombres ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.idTipoDocumento ?? null,
        dto.numeroDocumento ?? null,
        dto.direccion ?? null,
        dto.referencia ?? null,
        dto.latitud ?? null,
        dto.longitud ?? null,
        dto.idPais ?? null,
        dto.idDepartamento ?? null,
        dto.idProvincia ?? null,
        dto.idDistrito ?? null,
        dto.fechaNacimiento ?? null,
        dto.fechaInicio ?? null,
        dto.fechaCese ?? null,
        dto.idArea ?? null,
        dto.idCargo ?? null,
        dto.idUsuarioVinculo ?? null,
        dto.idChofer ?? null,
        dto.idUsuarioAuditoria ?? null,
        dto.correo ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('tra_eliminar_trabajador', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
