import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  FiltroBajaClienteDto,
  SolicitarBajaClienteDto,
} from '../dto/bajas-cliente.dto';
import { BajasClienteModel } from '../models/bajas-cliente.model';

@Injectable()
export class BajasClienteLogic {
  constructor(private readonly bajasClienteModel: BajasClienteModel) {}

  async listar(filtros: FiltroBajaClienteDto) {
    const result = await this.bajasClienteModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.bajasClienteModel.obtenerPorId(id);
    return mapSingleResult(result, `Solicitud de baja ${id} no encontrada`);
  }

  async solicitar(dto: SolicitarBajaClienteDto) {
    const result = await this.bajasClienteModel.solicitar(dto);
    return mapSingleResult(result, 'No se pudo crear la solicitud de baja');
  }

  async aprobar(idBaja: number, idUsuarioAuditoria?: number) {
    const result = await this.bajasClienteModel.aprobar(idBaja, idUsuarioAuditoria);
    return mapSingleResult(result, `Solicitud de baja ${idBaja} no encontrada`);
  }

  async rechazar(idBaja: number, idUsuarioAuditoria?: number) {
    const result = await this.bajasClienteModel.rechazar(idBaja, idUsuarioAuditoria);
    return mapSingleResult(result, `Solicitud de baja ${idBaja} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.bajasClienteModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Solicitud de baja ${id} no encontrada`);
  }
}
