import { Injectable } from '@nestjs/common';
import { mapDeleteResult, mapListResult, mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { ClientesModel } from '../models/clientes.model';
import { ValidarDocumentoClienteDto } from '../dto/validar-documento.dto';
import { ResponseHelper } from 'src/common/helpers/response.helper';
import { CreateClienteDto, UpdateClienteDto } from '../dto/crear-cliente.dto';

@Injectable()
export class ClientesLogic {
  constructor(private readonly clientesModel: ClientesModel) {}

  async listar(filtros: FiltroClienteDto) {
    const result = await this.clientesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.clientesModel.obtenerPorId(id);
    return mapSingleResult(result, `Cliente ${id} no encontrado`);
  }

  async eliminar(id: number) {
    const result = await this.clientesModel.eliminar(id);
    return mapDeleteResult(result, `Cliente ${id} no encontrado o ya está inactivo`);
  }

  async restaurar(id: number) {
    const result = await this.clientesModel.restaurar(id);
    return mapDeleteResult(result, `Cliente ${id} no encontrado o ya está activo`);
  }

  async validarDocumento(dto: ValidarDocumentoClienteDto) {
    const result = await this.clientesModel.validarDocumento(dto.numeroDocumento,dto.idExcluir,);
    return ResponseHelper.success(result, 'Validación de documento realizada');
  }

  async crear(dto: CreateClienteDto) {
    const result = await this.clientesModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el cliente');
  }

  async actualizar(id: number, dto: UpdateClienteDto) {
    const result = await this.clientesModel.actualizar(id, dto);
    return mapSingleResult(result, `Cliente ${id} no encontrado`);
  }
}
