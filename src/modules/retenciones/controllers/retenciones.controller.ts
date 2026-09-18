import {
  Body,
  Controller,
  Get,
  Header,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Req,
  StreamableFile,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import {
  ComprasElegiblesQueryDto,
  CreateRetencionDto,
  FiltroRetencionDto,
  SeriesRetencionQueryDto,
} from '../dto/retencion.dto';
import { RetencionesLogic } from '../logic/retenciones.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Retenciones')
@Controller('retenciones')
export class RetencionesController {
  constructor(private readonly logic: RetencionesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.RETENCIONES_LISTAR)
  @ApiOperation({ summary: 'Listar comprobantes de retención' })
  listar(@Query() filtros: FiltroRetencionDto) {
    return this.logic.listar(filtros);
  }

  @Get('catalogos')
  @Permisos(PermisoBanderas.RETENCIONES_LISTAR)
  @ApiOperation({ summary: 'Regímenes SUNAT de retención con las tasas registradas para cada uno y estados SUNAT' })
  catalogos() {
    return this.logic.catalogos();
  }

  @Get('series')
  @Permisos(PermisoBanderas.RETENCIONES_CREAR)
  @ApiOperation({ summary: 'Series de retención usadas por la empresa, con el último y el siguiente correlativo' })
  series(@Query() query: SeriesRetencionQueryDto) {
    return this.logic.series(query.idEmpresa);
  }

  @Get('compras-elegibles')
  @Permisos(PermisoBanderas.RETENCIONES_CREAR)
  @ApiOperation({ summary: 'Compras con factura de proveedor (RUC), en soles y sin retención, para armar una retención' })
  comprasElegibles(@Query() query: ComprasElegiblesQueryDto) {
    return this.logic.listarComprasElegibles(query);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.RETENCIONES_VER)
  @ApiOperation({ summary: 'Obtener retención por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Get(':id/pdf-oficial')
  @Permisos(PermisoBanderas.RETENCIONES_VER)
  @ApiOperation({ summary: 'Obtener PDF oficial de SUNAT' })
  @ApiProduces('application/pdf')
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  @Header('Content-Type', 'application/pdf')
  async obtenerPdfOficial(@Param('id', ParseIntPipe) id: number) {
    const resultado = await this.logic.obtenerPdfOficial(id);
    if (!resultado) throw new NotFoundException('No hay PDF oficial disponible');
    return new StreamableFile(resultado.buffer, {
      type: 'application/pdf',
      disposition: `inline; filename="${resultado.filename}"`,
    });
  }

  @Get(':id/xml-oficial')
  @Permisos(PermisoBanderas.RETENCIONES_VER)
  @ApiOperation({ summary: 'Obtener XML oficial de SUNAT' })
  @ApiProduces('application/xml')
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  @Header('Content-Type', 'application/xml')
  async obtenerXmlOficial(@Param('id', ParseIntPipe) id: number) {
    const resultado = await this.logic.obtenerXmlOficial(id);
    if (!resultado) throw new NotFoundException('No hay XML oficial disponible');
    return new StreamableFile(resultado.buffer, {
      type: 'application/xml',
      disposition: `attachment; filename="${resultado.filename}"`,
    });
  }

  @Post()
  @Permisos(PermisoBanderas.RETENCIONES_CREAR)
  @ApiOperation({ summary: 'Crear una retención a partir de compras registradas (queda pendiente de emisión)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  crear(@Body() dto: CreateRetencionDto, @Req() req: AuthRequest) {
    return this.logic.crear(dto, req.user.id);
  }

  @Post(':id/emitir')
  @Permisos(PermisoBanderas.RETENCIONES_EMITIR)
  @ApiOperation({ summary: 'Emitir retención a SUNAT (retention/send)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  emitir(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.emitir(id, dto);
  }

  @Post(':id/descargar-pdf-xml-sunat')
  @Permisos(PermisoBanderas.RETENCIONES_EMITIR)
  @ApiOperation({ summary: 'Descargar PDF y XML oficiales de SUNAT' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  descargarPdfXml(@Param('id', ParseIntPipe) id: number) {
    return this.logic.descargarPdfXml(id);
  }
}
