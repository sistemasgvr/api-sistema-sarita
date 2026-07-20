import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  StreamableFile,
} from '@nestjs/common';
import {
  ApiNotFoundResponse,
  ApiOperation,
  ApiProduces,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateGuiaRemisionDto,
  FiltroGuiaRemisionDto,
  SiguienteNumeroGuiaQueryDto,
  UpdateGuiaRemisionDto,
} from '../dto/guias-remision.dto';
import { GuiasRemisionLogic } from '../logic/guias-remision.logic';

@ApiTags('Guías de remisión')
@Controller('guias-remision')
export class GuiasRemisionController {
  constructor(private readonly logic: GuiasRemisionLogic) {}

  @Get()
  @Permisos(PermisoBanderas.GUIAS_REMISION_LISTAR)
  @ApiOperation({ summary: 'Listar guías de remisión' })
  listar(@Query() filtros: FiltroGuiaRemisionDto) {
    return this.logic.listar(filtros);
  }

  @Get('catalogos')
  @Permisos(PermisoBanderas.GUIAS_REMISION_LISTAR)
  @ApiOperation({ summary: 'Catálogos para formulario de GRE' })
  obtenerCatalogos() {
    return this.logic.obtenerCatalogos();
  }

  @Get('siguiente-numero')
  @Permisos(PermisoBanderas.GUIAS_REMISION_CREAR)
  @ApiOperation({ summary: 'Obtener siguiente correlativo por serie' })
  obtenerSiguienteNumero(@Query() query: SiguienteNumeroGuiaQueryDto) {
    return this.logic.obtenerSiguienteNumero(query);
  }

  @Get(':id/pdf')
  @Permisos(PermisoBanderas.GUIAS_REMISION_VER)
  @ApiOperation({ summary: 'Generar PDF A4 de la guía de remisión' })
  @ApiProduces('application/pdf')
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  @Header('Content-Type', 'application/pdf')
  async generarPdf(@Param('id', ParseIntPipe) id: number) {
    const { buffer, filename } = await this.logic.generarPdf(id);

    return new StreamableFile(buffer, {
      type: 'application/pdf',
      disposition: `inline; filename="${filename}"`,
    });
  }

  @Get(':id')
  @Permisos(PermisoBanderas.GUIAS_REMISION_VER)
  @ApiOperation({ summary: 'Obtener guía de remisión por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.GUIAS_REMISION_CREAR)
  @ApiOperation({ summary: 'Crear guía de remisión' })
  crear(@Body() dto: CreateGuiaRemisionDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.GUIAS_REMISION_EDITAR)
  @ApiOperation({ summary: 'Actualizar guía de remisión (solo no aceptada)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateGuiaRemisionDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.GUIAS_REMISION_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar guía de remisión (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto);
  }

  @Post(':id/emitir')
  @Permisos(PermisoBanderas.GUIAS_REMISION_EMITIR)
  @ApiOperation({ summary: 'Emitir guía de remisión a SUNAT (despatch/send)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  emitir(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.emitir(id, dto);
  }

  @Post(':id/consultar-estado')
  @Permisos(PermisoBanderas.GUIAS_REMISION_EMITIR)
  @ApiOperation({
    summary: 'Consultar estado SUNAT de la guía (despatch/status)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  consultarEstado(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.consultarEstado(id, dto);
  }
}
