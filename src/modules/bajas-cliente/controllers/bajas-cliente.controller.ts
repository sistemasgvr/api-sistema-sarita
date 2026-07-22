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
import {
  FiltroBajaClienteDto,
  SolicitarBajaClienteDto,
  SolicitarReactivacionClienteDto,
} from '../dto/bajas-cliente.dto';
import { BajasClienteLogic } from '../logic/bajas-cliente.logic';
import { Public } from '../../../common/decorators/public.decorator';

@ApiTags('Bajas de Cliente')
@Controller('bajas-cliente')
export class BajasClienteController {
  constructor(private readonly bajasClienteLogic: BajasClienteLogic) {}

  @Get()
  @Public()
  @ApiOperation({ summary: 'Listar solicitudes de baja de cliente' })
  listar(@Query() filtros: FiltroBajaClienteDto) {
    return this.bajasClienteLogic.listar(filtros);
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: 'Obtener solicitud de baja por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.bajasClienteLogic.obtenerPorId(id);
  }

  @Post()
  @Public()
  @ApiOperation({ summary: 'Solicitar baja de cliente (estado PENDIENTE)' })
  solicitar(@Body() dto: SolicitarBajaClienteDto) {
    return this.bajasClienteLogic.solicitar(dto);
  }

  @Post('solicitar-reactivacion')
  @Public()
  @ApiOperation({ summary: 'Solicitar reactivación de cliente (estado PENDIENTE)' })
  solicitarReactivacion(@Body() dto: SolicitarReactivacionClienteDto) {
    return this.bajasClienteLogic.solicitarReactivacion(dto);
  }

  @Patch(':id/aprobar')
  @Public()
  @ApiOperation({ summary: 'Aprobar solicitud de baja (cambia cliente a estado 0)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  aprobar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.bajasClienteLogic.aprobar(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id/rechazar')
  @Public()
  @ApiOperation({ summary: 'Rechazar solicitud de baja (cliente mantiene estado 1)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  rechazar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.bajasClienteLogic.rechazar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Public()
  @ApiOperation({ summary: 'Eliminar solicitud de baja (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.bajasClienteLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
