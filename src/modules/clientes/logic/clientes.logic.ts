import { Injectable } from '@nestjs/common';
import { mapListResult } from '../../../common/helpers/auth-response.helper';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { ClientesModel } from '../models/clientes.model';

@Injectable()
export class ClientesLogic {
  constructor(private readonly clientesModel: ClientesModel) {}

  async listar(filtros: FiltroClienteDto) {
    const result = await this.clientesModel.listar(filtros);
    return mapListResult(result, filtros);
  }
}
