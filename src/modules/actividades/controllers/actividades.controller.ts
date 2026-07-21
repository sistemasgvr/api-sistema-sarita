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
import { ApiNotFoundResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateActividadDto,
  FiltroActividadesDto,
  UpdateActividadDto,
} from '../dto/actividades.dto';
import { ActividadesLogic } from '../logic/actividades.logic';

@ApiTags('Operativa - Actividades')
@Controller('operativa/actividades')
export class ActividadesController {
  constructor(private readonly actividadesLogic: ActividadesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ACTIVIDADES_LISTAR)
  @ApiOperation({ summary: 'Listar actividades de la agenda' })
  listar(@Query() filtros: FiltroActividadesDto) {
    return this.actividadesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ACTIVIDADES_VER)
  @ApiOperation({ summary: 'Obtener actividad por ID' }) 
  @ApiOkResponse({ description: 'Actividad obtenida correctamente' }) 
  @ApiNotFoundResponse({ description: 'La actividad solicitada no existe o fue eliminada' })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.actividadesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ACTIVIDADES_CREAR)
  @ApiOperation({ summary: 'Crear actividad' })
  crear(@Body() dto: CreateActividadDto) {
    return this.actividadesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ACTIVIDADES_EDITAR)
  @ApiOperation({ summary: 'Actualizar actividad' })
  @ApiOkResponse({ description: 'Actividad actualizada correctamente' })
  @ApiNotFoundResponse({ description: 'La actividad que intenta actualizar no existe' })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateActividadDto,
  ) {
    return this.actividadesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ACTIVIDADES_ELIMINAR) 
  @ApiOperation({ summary: 'Eliminar actividad (baja lógica)' })
  @ApiOkResponse({ description: 'Actividad eliminada correctamente' }) 
  @ApiNotFoundResponse({ description: 'La actividad que intenta eliminar no existe o ya fue dada de baja' })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.actividadesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}