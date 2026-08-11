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
  CreateMovimientosRecargaDto,
  CreateRecargaClienteDto,
  FiltroMovimientosRecargaDto,
  FiltroOrigenRecargaDto,
  UpdateMovimientosRecargaDto,
  VincularRecargaClienteComprobanteDto,
} from '../dto/movimientos-recarga.dto';
import { MovimientosRecargaLogic } from '../logic/movimientos-recarga.logic';

@ApiTags('Balones - Movimientos Recarga')
@Controller('balones/movimientos-recarga')
export class MovimientosRecargaController {
  constructor(private readonly logic: MovimientosRecargaLogic) {}

  @Get()
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroMovimientosRecargaDto) {
    return this.logic.listar(filtros);
  }

  @Get('origenes-recarga')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_LISTAR)
  @ApiOperation({
    summary:
      'Lista balones EMPRESA LLENOS candidatos a origen de recarga (mismo gas, residual suficiente)',
  })
  listarOrigenes(@Query() filtros: FiltroOrigenRecargaDto) {
    return this.logic.listarOrigenes(filtros);
  }

  @Get('sugerir-origen')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_LISTAR)
  @ApiOperation({ summary: 'Sugiere balón empresa origen (FIFO)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  sugerirOrigen(@Query() filtros: FiltroOrigenRecargaDto) {
    return this.logic.sugerirOrigen(filtros);
  }

  @Get('asignar-origenes')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_LISTAR)
  @ApiOperation({
    summary:
      'Asigna balones empresa FIFO para cubrir la capacidad (puede usar varios si uno no alcanza)',
  })
  asignarOrigenes(@Query() filtros: FiltroOrigenRecargaDto) {
    return this.logic.asignarOrigenes(filtros);
  }

  @Post('recarga-cliente')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_CREAR)
  @ApiOperation({ summary: 'Recarga en mostrador (cliente trae balón + comprobante)' })
  crearRecargaCliente(@Body() dto: CreateRecargaClienteDto) {
    return this.logic.crearRecargaCliente(dto);
  }

  @Post('vincular-cliente-comprobante')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_CREAR)
  @ApiOperation({
    summary: 'Vincula recarga CLIENTE a un comprobante ya creado (POS unificado)',
  })
  vincularRecargaClienteComprobante(@Body() dto: VincularRecargaClienteComprobanteDto) {
    return this.logic.vincularRecargaClienteComprobante(dto);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreateMovimientosRecargaDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateMovimientosRecargaDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
