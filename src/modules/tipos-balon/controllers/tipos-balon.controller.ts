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
  CreateTiposBalonDto,
  FiltroTiposBalonDto,
  UpdateTiposBalonDto,
} from '../dto/tipos-balon.dto';
import { TiposBalonLogic } from '../logic/tipos-balon.logic';

@ApiTags('Balones - Tipos')
@Controller('balones/tipos')
export class TiposBalonController {
  constructor(private readonly logic: TiposBalonLogic) {}

  @Get()
  @Permisos(PermisoBanderas.TIPOS_BALON_LISTAR)
  @ApiOperation({ summary: 'Listar' })
  listar(@Query() filtros: FiltroTiposBalonDto) {
    return this.logic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.TIPOS_BALON_VER)
  @ApiOperation({ summary: 'Obtener por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.TIPOS_BALON_CREAR)
  @ApiOperation({ summary: 'Crear' })
  crear(@Body() dto: CreateTiposBalonDto) {
    return this.logic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.TIPOS_BALON_EDITAR)
  @ApiOperation({ summary: 'Actualizar' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateTiposBalonDto,
  ) {
    return this.logic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.TIPOS_BALON_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.logic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
