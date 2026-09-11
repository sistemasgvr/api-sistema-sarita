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
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthRequest } from '../../../common/interfaces/auth-request.interface';
import {
  AplicarLoteProtocoloDto,
  CreateLoteProtocoloDto,
  FiltroHistorialLoteProtocoloDto,
  FiltroLotesProtocoloDto,
  UpdateLoteProtocoloDto,
} from '../dto/lotes-protocolo.dto';
import { LotesProtocoloLogic } from '../logic/lotes-protocolo.logic';

@ApiTags('Balones - Lote y Protocolo (ICP)')
@Controller('balones/lotes-protocolo')
export class LotesProtocoloController {
  constructor(private readonly logic: LotesProtocoloLogic) {}

  @Get()
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_LISTAR)
  @ApiOperation({ summary: 'Listar fichas de lote y protocolo' })
  listar(@Query() filtros: FiltroLotesProtocoloDto) {
    return this.logic.listar(filtros);
  }

  @Get('balon/:idBalon/historial')
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_LISTAR)
  @ApiOperation({
    summary:
      'Historial de fichas de un cilindro (se deriva de sus recargas) + la ficha vigente en meta.resumen',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  historialPorBalon(
    @Param('idBalon', ParseIntPipe) idBalon: number,
    @Query() filtros: FiltroHistorialLoteProtocoloDto,
  ) {
    return this.logic.historialPorBalon(idBalon, filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_VER)
  @ApiOperation({
    summary: 'Obtener ficha completa (cabecera + análisis + envases)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_CREAR)
  @ApiOperation({ summary: 'Registrar ficha de lote y protocolo' })
  crear(@Body() dto: CreateLoteProtocoloDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.crear(dto);
  }

  @Post(':id/aplicar-balones')
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_EDITAR)
  @ApiOperation({
    summary:
      'Marca la ficha como vigente en los cilindros indicados (ingreso por compra / retorno de planta)',
  })
  aplicarABalones(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AplicarLoteProtocoloDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.aplicarABalones(id, dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_EDITAR)
  @ApiOperation({ summary: 'Editar ficha de lote y protocolo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateLoteProtocoloDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.LOTES_PROTOCOLO_ELIMINAR)
  @ApiOperation({
    summary: 'Eliminar ficha (no permitido si alguna recarga la referencia)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
