import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
//import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
//import { Permisos } from '../../../common/decorators/permisos.decorator';
import { Public } from '../../../common/decorators/public.decorator';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { ClientesLogic } from '../logic/clientes.logic';

@ApiTags('Clientes')
@Controller('clientes')
export class ClientesController {
  constructor(private readonly clientesLogic: ClientesLogic) {}
  @Get()
  @Public()
  //@Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({ summary: 'Listar clientes generales' })
  listar(@Query() filtros: FiltroClienteDto) {
    return this.clientesLogic.listar(filtros);
  }
}
