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
  CreateRecargaPlantaDto,
  FiltroRecargasPlantaDto,
  UpdateRecargaPlantaDto,
} from '../dto/recargas-planta.dto';
import { RecargasPlantaLogic } from '../logic/recargas-planta.logic';
import { Public } from '../../../common/decorators/public.decorator';

@ApiTags('Balones - Recargas planta externa')
@Controller('balones/recargas-planta')
export class RecargasPlantaController {
  constructor(private readonly logic: RecargasPlantaLogic) {}

  @Get()
  @Public()
  //@Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_LISTAR)
  @ApiOperation({ summary: 'Listar órdenes de recarga en planta externa' })
  listar(@Query() filtros: FiltroRecargasPlantaDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Public()
  //@Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_VER)
  @ApiOperation({ summary: 'Obtener orden con detalle' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_CREAR)
  @ApiOperation({
    summary:
      'Registrar salida de recarga (checklist). Puede jalar idGuiaSalida y detalle de cilindros.',
  })
  crear(@Body() dto: CreateRecargaPlantaDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_EDITAR)
  @ApiOperation({ summary: 'Actualizar retorno, lote, GRE ingreso o compra' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRecargaPlantaDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.MOVIMIENTOS_RECARGA_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar orden (solo borrador/enviado)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
