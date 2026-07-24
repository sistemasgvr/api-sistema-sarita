import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { FiltroClienteMapaDto } from '../dto/filtros-cliente-mapa.dto';
import { ClientesModel } from '../models/clientes.model';
import { ValidarDocumentoClienteDto } from '../dto/validar-documento.dto';
import { CreateClienteDto, UpdateClienteDto } from '../dto/crear-cliente.dto';
import { esClientesVarios } from '../constants/clientes-varios';

@Injectable()
export class ClientesLogic {
  constructor(private readonly clientesModel: ClientesModel) {}

  async listar(filtros: FiltroClienteDto) {
    const result = await this.clientesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async listarMapa(filtros: FiltroClienteMapaDto) {
    const result = await this.clientesModel.listarMapa(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.clientesModel.obtenerPorId(id);
    return mapSingleResult(result, `Cliente ${id} no encontrado`);
  }

  private async assertNoEsClientesVarios(id: number, accion: string) {
    const cliente = await this.obtenerPorId(id);
    if (esClientesVarios(cliente as { codigo_interno?: string | null })) {
      throw new BadRequestException(
        `No se puede ${accion} el cliente de sistema Clientes Varios (CVARIOS)`,
      );
    }
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    await this.assertNoEsClientesVarios(id, 'archivar');
    const result = await this.clientesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Cliente ${id} no encontrado o ya está inactivo`);
  }

  async restaurar(id: number, idUsuarioAuditoria?: number) {
    await this.assertNoEsClientesVarios(id, 'restaurar');
    const result = await this.clientesModel.restaurar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Cliente ${id} no encontrado o ya está activo`);
  }

  async validarDocumento(dto: ValidarDocumentoClienteDto) {
    return this.clientesModel.validarDocumento(dto.numeroDocumento, dto.idExcluir);
  }

  async crear(dto: CreateClienteDto) {
    if ((dto.codigoInterno ?? '').trim().toUpperCase() === 'CVARIOS') {
      throw new BadRequestException(
        'El código interno CVARIOS está reservado para el cliente de sistema',
      );
    }
    const result = await this.clientesModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el cliente');
  }

  async actualizar(id: number, dto: UpdateClienteDto) {
    await this.assertNoEsClientesVarios(id, 'editar');
    if ((dto.codigoInterno ?? '').trim().toUpperCase() === 'CVARIOS') {
      throw new BadRequestException(
        'El código interno CVARIOS está reservado para el cliente de sistema',
      );
    }
    const result = await this.clientesModel.actualizar(id, dto);
    return mapSingleResult(result, `Cliente ${id} no encontrado`);
  }
}
