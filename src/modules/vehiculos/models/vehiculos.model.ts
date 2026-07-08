import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateVehiculoDto,
  FiltroVehiculoDto,
  UpdateVehiculoDto,
} from '../dto/vehiculos.dto';

@Injectable()
export class VehiculosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroVehiculoDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_vehiculos', [
      filtros.isActivos ?? 1,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.pagina?? 1,
      filtros.idCliente ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_obtener_vehiculo',
      [id],
    );
  }

  crear(dto: CreateVehiculoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_crear_vehiculo',
      [
        dto.placa,
        dto.idCliente ?? null,
        dto.idTipoVehiculo ?? null,
        dto.placa2 ?? null,
        dto.marca ?? null,
        dto.marca2 ?? null,
        dto.modelo ?? null,
        dto.anio ?? null,
        dto.color ?? null,
        dto.certificadoInscripcion ?? null,
        dto.certificado2 ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateVehiculoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_actualizar_vehiculo',
      [
        id,
        dto.idCliente ?? null,
        dto.idTipoVehiculo ?? null,
        dto.placa ?? null,
        dto.placa2 ?? null,
        dto.marca ?? null,
        dto.marca2 ?? null,
        dto.modelo ?? null,
        dto.anio ?? null,
        dto.color ?? null,
        dto.certificadoInscripcion ?? null,
        dto.certificado2 ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_vehiculo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
