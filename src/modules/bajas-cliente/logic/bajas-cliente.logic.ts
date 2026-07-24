import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ClientesLogic } from '../../clientes/logic/clientes.logic';
import { esClientesVarios } from '../../clientes/constants/clientes-varios';
import {
  FiltroBajaClienteDto,
  SolicitarBajaClienteDto,
  SolicitarReactivacionClienteDto,
} from '../dto/bajas-cliente.dto';
import { BajasClienteModel } from '../models/bajas-cliente.model';

@Injectable()
export class BajasClienteLogic {
  constructor(
    private readonly bajasClienteModel: BajasClienteModel,
    private readonly clientesLogic: ClientesLogic,
  ) {}

  async listar(filtros: FiltroBajaClienteDto) {
    const result = await this.bajasClienteModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.bajasClienteModel.obtenerPorId(id);
    return mapSingleResult(result, `Solicitud de baja ${id} no encontrada`);
  }

  private async assertNoEsClientesVarios(idCliente: number) {
    const cliente = await this.clientesLogic.obtenerPorId(idCliente);
    if (esClientesVarios(cliente as { codigo_interno?: string | null })) {
      throw new BadRequestException(
        'No se puede solicitar baja/reactivación del cliente de sistema Clientes Varios (CVARIOS)',
      );
    }
  }

  async solicitarReactivacion(dto: SolicitarReactivacionClienteDto) {
    await this.assertNoEsClientesVarios(dto.idCliente);
    const result = await this.bajasClienteModel.solicitarReactivacion(dto);
    return mapSingleResult(result, 'No se pudo crear la solicitud de reactivación');
  }

  async solicitar(dto: SolicitarBajaClienteDto) {
    await this.assertNoEsClientesVarios(dto.idCliente);
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
