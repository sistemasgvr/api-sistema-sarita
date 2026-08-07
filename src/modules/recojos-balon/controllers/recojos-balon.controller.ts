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
  CreateRecojosBalonDto,
  FiltroPendientesRecojoDto,
  FiltroRecojosBalonDto,
  RegistrarResultadoRecojoDto,
  UpdateRecojosBalonDto,
} from '../dto/recojos-balon.dto';
import { RecojosBalonLogic } from '../logic/recojos-balon.logic';

@ApiTags('Balones - Recojos')
@Controller('balones/recojos')
export class RecojosBalonController {
  constructor(private readonly logic: RecojosBalonLogic) {}

  @Get()
  @Permisos(PermisoBanderas.RECOJOS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar visitas de recojo' })
  listar(@Query() filtros: FiltroRecojosBalonDto) {
    return this.logic.listar(filtros);
  }

  @Get('pendientes')
  @Permisos(PermisoBanderas.RECOJOS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar cilindros pendientes de recojo de préstamos y alquileres activos' })
  listarPendientes(@Query() filtros: FiltroPendientesRecojoDto) {
    return this.logic.listarPendientes(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.RECOJOS_BALON_VER)
  @ApiOperation({ summary: 'Obtener recojo con detalles' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.RECOJOS_BALON_CREAR)
  @ApiOperation({ summary: 'Programar visita de recojo (PROGRAMADO)' })
  crear(@Body() dto: CreateRecojosBalonDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.RECOJOS_BALON_EDITAR)
  @ApiOperation({ summary: 'Actualizar programación / estado (EN_RUTA, CANCELADO)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRecojosBalonDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Post(':id/registrar-resultado')
  @Permisos(PermisoBanderas.RECOJOS_BALON_EDITAR)
  @ApiOperation({
    summary:
      'Registrar resultado de visita (RECOGIDO / NO_RECOGIDO / EXTENDIDO) y recalcular estado',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  registrarResultado(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarResultadoRecojoDto,
  ) {
    return this.logic.registrarResultado(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.RECOJOS_BALON_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar recojo (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
