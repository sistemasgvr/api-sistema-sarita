import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Query,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroArchivosDto } from '../dto/archivos.dto';
import { ArchivosLogic } from '../logic/archivos.logic';

@ApiTags('Archivos')
@Controller('archivos')
export class ArchivosController {
  constructor(private readonly archivosLogic: ArchivosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Listar metadatos de archivos' })
  listar(@Query() filtros: FiltroArchivosDto) {
    return this.archivosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Obtener archivo por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.archivosLogic.obtenerPorId(id);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({
    summary: 'Eliminar registro de archivo (soft delete; no borra del bucket)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.archivosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
