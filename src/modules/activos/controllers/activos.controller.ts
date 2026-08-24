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
  CreateActivoDto,
  FiltroActivoDto,
  UpdateActivoDto,
} from '../dto/activos.dto';
import { ActivosLogic } from '../logic/activos.logic';

@ApiTags('Activos')
@Controller('activos')
export class ActivosController {
  constructor(private readonly activosLogic: ActivosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ACTIVO_LISTAR)
  @ApiOperation({ summary: 'Listar activos de la empresa' })
  listar(@Query() filtros: FiltroActivoDto) {
    return this.activosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ACTIVO_VER)
  @ApiOperation({ summary: 'Obtener activo por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.activosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ACTIVO_CREAR)
  @ApiOperation({ summary: 'Crear activo' })
  crear(@Body() dto: CreateActivoDto) {
    return this.activosLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ACTIVO_EDITAR)
  @ApiOperation({ summary: 'Actualizar activo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateActivoDto,
  ) {
    return this.activosLogic.actualizar(id, dto);
  }

  @Delete(':id')  
  @Permisos(PermisoBanderas.ACTIVO_ELIMINAR)
  @ApiOperation({ summary: 'Dar de baja a activo (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.activosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}