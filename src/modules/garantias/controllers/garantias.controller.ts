import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import {
  CreateGarantiaDto,
  DevolverGarantiaDto,
  FiltroGarantiasDto,
} from '../dto/garantias.dto';
import { GarantiasLogic } from '../logic/garantias.logic';

@ApiTags('Ventas - Garantías')
@Controller('garantias')
export class GarantiasController {
  constructor(private readonly logic: GarantiasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar garantías (filtro por cliente / préstamo)' })
  listar(@Query() filtros: FiltroGarantiasDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_VER)
  @ApiOperation({ summary: 'Obtener garantía por ID (incluye movimientos)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_CREAR)
  @ApiOperation({ summary: 'Cobrar garantía (crea ACTIVA + movimiento COBRO)' })
  crear(@Body() dto: CreateGarantiaDto) {
    return this.logic.crear(dto);
  }

  @Post(':id/devolver')
  @Permisos(PermisoBanderas.PRESTAMOS_BALON_EDITAR)
  @ApiOperation({
    summary: 'Devolver garantía (parcial/total; actualiza saldo y estado)',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  devolver(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: DevolverGarantiaDto,
  ) {
    return this.logic.devolver(id, dto);
  }
}
