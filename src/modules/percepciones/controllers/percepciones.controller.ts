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
  ComprobantesElegiblesQueryDto,
  CreatePercepcionDto,
  FiltroPercepcionDto,
  SeriesPercepcionQueryDto,
} from '../dto/percepcion.dto';
import { PercepcionesLogic } from '../logic/percepciones.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Percepciones')
@Controller('percepciones')
export class PercepcionesController {
  constructor(private readonly logic: PercepcionesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.PERCEPCIONES_LISTAR)
  @ApiOperation({ summary: 'Listar comprobantes de percepción' })
  listar(@Query() filtros: FiltroPercepcionDto) {
    return this.logic.listar(filtros);
  }

  @Get('catalogos')
  @Permisos(PermisoBanderas.PERCEPCIONES_LISTAR)
  @ApiOperation({ summary: 'Regímenes SUNAT de percepción con las tasas registradas para cada uno y estados SUNAT' })
  catalogos() {
    return this.logic.catalogos();
  }

  @Get('series')
  @Permisos(PermisoBanderas.PERCEPCIONES_CREAR)
  @ApiOperation({ summary: 'Series de percepción usadas por la empresa, con el último y el siguiente correlativo' })
  series(@Query() query: SeriesPercepcionQueryDto) {
    return this.logic.series(query.idEmpresa);
  }

  @Get('comprobantes-elegibles')
  @Permisos(PermisoBanderas.PERCEPCIONES_CREAR)
  @ApiOperation({ summary: 'Facturas/boletas aceptadas por SUNAT, en soles y sin percepción, para armar una percepción' })
  comprobantesElegibles(@Query() query: ComprobantesElegiblesQueryDto) {
    return this.logic.listarComprobantesElegibles(query);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PERCEPCIONES_VER)
  @ApiOperation({ summary: 'Obtener percepción por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Get(':id/pdf-oficial')
  @Permisos(PermisoBanderas.PERCEPCIONES_VER)
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
  @Permisos(PermisoBanderas.PERCEPCIONES_VER)
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
  @Permisos(PermisoBanderas.PERCEPCIONES_CREAR)
  @ApiOperation({ summary: 'Crear una percepción a partir de comprobantes de venta aceptados por SUNAT (queda pendiente de emisión)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  crear(@Body() dto: CreatePercepcionDto, @Req() req: AuthRequest) {
    return this.logic.crear(dto, req.user.id);
  }

  @Post(':id/emitir')
  @Permisos(PermisoBanderas.PERCEPCIONES_EMITIR)
  @ApiOperation({ summary: 'Emitir percepción a SUNAT (perception/send)' })
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
  @Permisos(PermisoBanderas.PERCEPCIONES_EMITIR)
  @ApiOperation({ summary: 'Descargar PDF y XML oficiales de SUNAT' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  descargarPdfXml(@Param('id', ParseIntPipe) id: number) {
    return this.logic.descargarPdfXml(id);
  }
}
