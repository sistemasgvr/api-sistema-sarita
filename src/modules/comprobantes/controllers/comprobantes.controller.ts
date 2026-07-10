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
  CreateComprobantesDto,
  FiltroComprobantesDto,
  RegistrarRespuestaSunatDto,
  SiguienteNumeroQueryDto,
  UpdateComprobantesDto,
} from '../dto/comprobantes.dto';
import { ComprobantesLogic } from '../logic/comprobantes.logic';

@ApiTags('Comprobantes')
@Controller('comprobantes')
export class ComprobantesController {
  constructor(private readonly logic: ComprobantesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.COMPROBANTES_LISTAR)
  @ApiOperation({ summary: 'Listar comprobantes de venta' })
  listar(@Query() filtros: FiltroComprobantesDto) {
    return this.logic.listar(filtros);
  }

  @Get('catalogos/pos')
  @Permisos(PermisoBanderas.COMPROBANTES_CREAR)
  @ApiOperation({ summary: 'Catálogos para punto de venta' })
  obtenerCatalogosPos() {
    return this.logic.obtenerCatalogosPos();
  }

  @Get('siguiente-numero')
  @Permisos(PermisoBanderas.COMPROBANTES_CREAR)
  @ApiOperation({ summary: 'Obtener siguiente número correlativo por serie y tipo' })
  obtenerSiguienteNumero(@Query() query: SiguienteNumeroQueryDto) {
    return this.logic.obtenerSiguienteNumero(query);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.COMPROBANTES_VER)
  @ApiOperation({ summary: 'Obtener comprobante por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.COMPROBANTES_CREAR)
  @ApiOperation({ summary: 'Crear comprobante de venta' })
  crear(@Body() dto: CreateComprobantesDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.COMPROBANTES_EDITAR)
  @ApiOperation({ summary: 'Actualizar comprobante (solo si SUNAT está pendiente)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateComprobantesDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Post(':id/emitir')
  @Permisos(PermisoBanderas.COMPROBANTES_EMITIR)
  @ApiOperation({ summary: 'Emitir comprobante ante SUNAT vía APIsPERU' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  emitir(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.emitir(id, dto);
  }

  @Post(':id/respuesta-sunat')
  @Permisos(PermisoBanderas.COMPROBANTES_EMITIR)
  @ApiOperation({ summary: 'Registrar respuesta SUNAT (xml, hash, CDR, ticket)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  registrarRespuestaSunat(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarRespuestaSunatDto,
  ) {
    return this.logic.registrarRespuestaSunat(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.COMPROBANTES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar comprobante (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto);
  }
}
