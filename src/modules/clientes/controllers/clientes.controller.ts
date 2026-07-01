import { Body, Controller, Delete, Get, Param, Patch, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
//import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
//import { Permisos } from '../../../common/decorators/permisos.decorator';
import { Public } from '../../../common/decorators/public.decorator';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { ClientesLogic } from '../logic/clientes.logic';
import { ClienteIdDto } from '../dto/id-cliente.dto';
import { ValidarDocumentoClienteDto } from '../dto/validar-documento.dto';
import { CreateClienteDto, UpdateClienteDto } from '../dto/crear-cliente.dto';

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

  @Get('/buscar/:id')
  @Public() 
  //@Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({ summary: 'Obtener cliente por ID' })
  obtenerPorId(@Param() params: ClienteIdDto) {
    return this.clientesLogic.obtenerPorId(params.id);
  }

  @Delete('/eliminar/:id')
  @Public()
  // @Permisos(PermisoBanderas.CLIENTES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar cliente (baja lógica)' })
  // Reutilizamos el ClienteIdDto
  eliminar(@Param() params: ClienteIdDto) {
    return this.clientesLogic.eliminar(params.id);
  }

  @Patch('/restaurar/:id')
  @Public()
  // @Permisos(PermisoBanderas.CLIENTES_RESTAURAR)
  @ApiOperation({ summary: 'Restaurar cliente (reactivar)' })
  // Reutilizamos el ClienteIdDto
  restaurar(@Param() params: ClienteIdDto) {
    return this.clientesLogic.restaurar(params.id);
  }

  @Get('validar-documento')
  @Public()
  // @Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({ summary: 'Validar si un número de documento (DNI, RUC O CE) ya está registrado' })
  validarDocumento(@Query() dto: ValidarDocumentoClienteDto) {
    return this.clientesLogic.validarDocumento(dto);
  }

  @Post()
  @Public()
  // @Permisos(PermisoBanderas.CLIENTES_CREAR)
  @ApiOperation({ summary: 'Crear cliente' })
  crear(@Body() dto: CreateClienteDto) {
    return this.clientesLogic.crear(dto);
  }
  
  @Patch(':id')
  @Public()
  // @Permisos(PermisoBanderas.CLIENTES_EDITAR)
  @ApiOperation({ summary: 'Actualizar cliente' })
  actualizar(@Param() params: ClienteIdDto, @Body() dto: UpdateClienteDto) {
    return this.clientesLogic.actualizar(params.id, dto);
  }
}
