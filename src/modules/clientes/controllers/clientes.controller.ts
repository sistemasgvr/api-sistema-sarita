import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { ClientesLogic } from '../logic/clientes.logic';
import { ValidarDocumentoClienteDto } from '../dto/validar-documento.dto';
import { CreateClienteDto, UpdateClienteDto } from '../dto/crear-cliente.dto';

@ApiTags('Clientes')
@Controller('clientes')
export class ClientesController {
  constructor(private readonly clientesLogic: ClientesLogic) {}

  @Get('validar-documento')
  @Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({
    summary: 'Validar si un número de documento ya está registrado',
  })
  validarDocumento(@Query() dto: ValidarDocumentoClienteDto) {
    return this.clientesLogic.validarDocumento(dto);
  }

  @Get()
  @Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({ summary: 'Listar clientes' })
  listar(@Query() filtros: FiltroClienteDto) {
    return this.clientesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CLIENTES_VER)
  @ApiOperation({ summary: 'Obtener cliente por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.clientesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CLIENTES_CREAR)
  @ApiOperation({ summary: 'Crear cliente' })
  crear(@Body() dto: CreateClienteDto) {
    return this.clientesLogic.crear(dto);
  }

  @Patch(':id/restaurar')
  @Permisos(PermisoBanderas.CLIENTES_RESTAURAR)
  @ApiOperation({ summary: 'Restaurar cliente (reactivar)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  restaurar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.clientesLogic.restaurar(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CLIENTES_EDITAR)
  @ApiOperation({ summary: 'Actualizar cliente' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateClienteDto,
  ) {
    return this.clientesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CLIENTES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar cliente (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.clientesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
