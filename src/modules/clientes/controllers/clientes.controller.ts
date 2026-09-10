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
  Req,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import { FiltroClienteDto } from '../dto/filtros-cliente.dto';
import { FiltroClienteMapaDto } from '../dto/filtros-cliente-mapa.dto';
import { ClientesLogic } from '../logic/clientes.logic';
import { ValidarDocumentoClienteDto } from '../dto/validar-documento.dto';
import { CreateClienteDto, UpdateClienteDto } from '../dto/crear-cliente.dto';
import { ExportarRelacionadosClienteDto } from '../dto/exportar-relacionados-cliente.dto';

type AuthRequest = Request & { user: AuthenticatedUser };

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

  @Get('mapa')
  @Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({
    summary:
      'Listar clientes con coordenadas para mapa (incluye balones en préstamo/alquiler/propios)',
  })
  listarMapa(@Query() filtros: FiltroClienteMapaDto) {
    return this.clientesLogic.listarMapa(filtros);
  }

  @Get()
  @Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({ summary: 'Listar clientes' })
  listar(@Query() filtros: FiltroClienteDto) {
    return this.clientesLogic.listar(filtros);
  }

  @Post('exportar-relacionados')
  @Permisos(PermisoBanderas.CLIENTES_LISTAR)
  @ApiOperation({
    summary:
      'Direcciones, vehículos, choferes y cuentas bancarias de un lote de clientes en una sola consulta agregada (uso: exportación a Excel)',
  })
  exportarRelacionados(@Body() dto: ExportarRelacionadosClienteDto) {
    return this.clientesLogic.exportarRelacionados(dto);
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
  crear(@Body() dto: CreateClienteDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.clientesLogic.crear(dto);
  }

  @Patch(':id/restaurar')
  @Permisos(PermisoBanderas.AUTH_TODO)
  @ApiOperation({
    summary:
      'Restaurar cliente (reactivar) — solo auth.todo; preferir flujo de solicitud/aprobación de baja',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  restaurar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.clientesLogic.restaurar(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CLIENTES_EDITAR)
  @ApiOperation({ summary: 'Actualizar cliente' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateClienteDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.clientesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.AUTH_TODO)
  @ApiOperation({
    summary:
      'Eliminar cliente (baja lógica) — solo auth.todo; valida deudas/préstamos/alquileres; preferir flujo de solicitud/aprobación',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.clientesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
