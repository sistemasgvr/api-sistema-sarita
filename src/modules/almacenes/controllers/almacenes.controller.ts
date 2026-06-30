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
  CreateAlmacenDto,
  FiltroAlmacenesDto,
  UpdateAlmacenDto,
} from '../dto/almacenes.dto';
import { AlmacenesLogic } from '../logic/almacenes.logic';

@ApiTags('Configuracion - Almacenes')
@Controller('configuracion/almacenes')
export class AlmacenesController {
  constructor(private readonly almacenesLogic: AlmacenesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.ALMACENES_LISTAR)
  @ApiOperation({ summary: 'Listar almacenes' })
  listar(@Query() filtros: FiltroAlmacenesDto) {
    return this.almacenesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.ALMACENES_VER)
  @ApiOperation({ summary: 'Obtener almacén por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.almacenesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.ALMACENES_CREAR)
  @ApiOperation({ summary: 'Crear almacén' })
  crear(@Body() dto: CreateAlmacenDto) {
    return this.almacenesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.ALMACENES_EDITAR)
  @ApiOperation({ summary: 'Actualizar almacén' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAlmacenDto,
  ) {
    return this.almacenesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.ALMACENES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar almacén (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.almacenesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
