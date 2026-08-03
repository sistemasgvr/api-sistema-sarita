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

@ApiTags('Bajas de Cliente')
@Controller('bajas-cliente')
export class BajasClienteController {
  constructor(private readonly bajasClienteLogic: BajasClienteLogic) {}

  @Get()
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_LISTAR)
  @ApiOperation({ summary: 'Listar solicitudes de baja de cliente' })
  listar(@Query() filtros: FiltroBajaClienteDto) {
    return this.bajasClienteLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_VER)
  @ApiOperation({ summary: 'Obtener solicitud de baja por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.bajasClienteLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_SOLICITAR)
  @ApiOperation({ summary: 'Solicitar baja de cliente (estado PENDIENTE)' })
  solicitar(@Body() dto: SolicitarBajaClienteDto) {
    return this.bajasClienteLogic.solicitar(dto);
  }

  @Post('solicitar-reactivacion')
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_SOLICITAR)
  @ApiOperation({ summary: 'Solicitar reactivación de cliente (estado PENDIENTE)' })
  solicitarReactivacion(@Body() dto: SolicitarReactivacionClienteDto) {
    return this.bajasClienteLogic.solicitarReactivacion(dto);
  }

  @Patch(':id/aprobar')
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_APROBAR)
  @ApiOperation({
    summary:
      'Aprobar solicitud (admin + permiso). Baja desactiva cliente; reactivación lo activa.',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  aprobar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.bajasClienteLogic.aprobar(id, dto.idUsuarioAuditoria);
  }

  @Patch(':id/rechazar')
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_RECHAZAR)
  @ApiOperation({ summary: 'Rechazar solicitud de baja/reactivación (admin + permiso)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  rechazar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.bajasClienteLogic.rechazar(id, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.BAJAS_CLIENTE_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar solicitud de baja (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.bajasClienteLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
