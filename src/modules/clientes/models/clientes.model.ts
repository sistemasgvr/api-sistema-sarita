import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { AuthListResult } from '../../../common/interfaces/auth-db.interface';

@Injectable()
export class ClientesModel {
  constructor(private readonly db: DatabaseService) {}
  listar(filtros: FiltroClienteDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_clientes', [
      filtros.soloActivos ?? true,
      filtros.idTipoCliente ?? null,
      filtros.busqueda ?? null,
      filtros.limite ?? 50,
      filtros.pagina ?? 1,
    ]);
  }
}
