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
  CreateDocumentoVencimientoDto,
  FiltroDocumentoVencimientoDto,
  UpdateDocumentoVencimientoDto,
} from '../dto/documentos-vencimiento.dto';
import { DocumentosVencimientoLogic } from '../logic/documentos-vencimiento.logic';
import { Public } from '../../../common/decorators/public.decorator';

@ApiTags('Documentos de Vencimiento')
@Controller('documentos-vencimiento')
export class DocumentosVencimientoController {
  constructor(private readonly documentosVencimientoLogic: DocumentosVencimientoLogic) {}

  @Get()
  @Public()
  @ApiOperation({ summary: 'Listar documentos de vencimiento' })
  listar(@Query() filtros: FiltroDocumentoVencimientoDto) {
    return this.documentosVencimientoLogic.listar(filtros);
  }

  @Get(':id')
  @Public()
  @ApiOperation({ summary: 'Obtener documento de vencimiento por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.documentosVencimientoLogic.obtenerPorId(id);
  }

  @Post()
  @Public()
  @ApiOperation({ summary: 'Crear documento de vencimiento' })
  crear(@Body() dto: CreateDocumentoVencimientoDto) {
    return this.documentosVencimientoLogic.crear(dto);
  }

  @Patch(':id')
  @Public()
  @ApiOperation({ summary: 'Actualizar documento de vencimiento' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateDocumentoVencimientoDto,
  ) {
    return this.documentosVencimientoLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Public()
  @ApiOperation({ summary: 'Eliminar documento de vencimiento (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.documentosVencimientoLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
