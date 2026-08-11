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
  CerrarRutaPuebloDto,
  CreateRutaPuebloDto,
  FiltroRutasPueblosDto,
  RegistrarRetornoRutaPuebloDto,
  UpdateRutaPuebloDto,
} from '../dto/rutas-pueblos.dto';
import { RutasPueblosLogic } from '../logic/rutas-pueblos.logic';

@ApiTags('Balones - Rutas pueblos')
@Controller('balones/rutas-pueblos')
export class RutasPueblosController {
  constructor(private readonly logic: RutasPueblosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_LISTAR)
  @ApiOperation({ summary: 'Listar controles de ruta a pueblos' })
  listar(@Query() filtros: FiltroRutasPueblosDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_VER)
  @ApiOperation({ summary: 'Obtener ruta con cilindros y libras' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_CREAR)
  @ApiOperation({ summary: 'Crear ruta ABIERTA con cilindros y lb de salida' })
  crear(@Body() dto: CreateRutaPuebloDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar cabecera / cancelar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRutaPuebloDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Post(':id/iniciar')
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_EDITAR)
  @ApiOperation({ summary: 'Pasar a EN_RUTA y mover cilindros (TRASLADO)' })
  iniciar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.logic.iniciar(id, dto.idUsuarioAuditoria);
  }

  @Post(':id/registrar-retorno')
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_EDITAR)
  @ApiOperation({
    summary: 'Registrar lb retorno → Δ m³ y residual en almacén (no fuerza vacío)',
  })
  registrarRetorno(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarRetornoRutaPuebloDto,
  ) {
    return this.logic.registrarRetorno(id, dto);
  }

  @Post(':id/cerrar')
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_EDITAR)
  @ApiOperation({ summary: 'Cerrar ruta cruzando m³ calculados vs reportados' })
  cerrar(@Param('id', ParseIntPipe) id: number, @Body() dto: CerrarRutaPuebloDto) {
    return this.logic.cerrar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.RUTAS_PUEBLOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar ruta (baja lógica)' })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
