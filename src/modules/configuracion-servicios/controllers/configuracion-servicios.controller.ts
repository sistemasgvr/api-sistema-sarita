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
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  CreateConfiguracionServicioDto,
  UpdateConfiguracionServicioDto,
} from '../dto/configuracion-servicios.dto';
import { ConfiguracionServiciosLogic } from '../logic/configuracion-servicios.logic';

@ApiTags('Configuracion - Servicios')
@Controller('configuracion/servicios')
export class ConfiguracionServiciosController {
  constructor(
    private readonly configuracionServiciosLogic: ConfiguracionServiciosLogic,
  ) {}

  @Get()
  @Permisos(PermisoBanderas.CONFIGURACION_SERVICIOS_LISTAR)
  @ApiOperation({ summary: 'Listar configuraciones de servicios' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.configuracionServiciosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SERVICIOS_VER)
  @ApiOperation({ summary: 'Obtener configuración de servicio por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.configuracionServiciosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CONFIGURACION_SERVICIOS_CREAR)
  @ApiOperation({ summary: 'Crear configuración de servicio' })
  crear(@Body() dto: CreateConfiguracionServicioDto) {
    return this.configuracionServiciosLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SERVICIOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar configuración de servicio' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateConfiguracionServicioDto,
  ) {
    return this.configuracionServiciosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SERVICIOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar configuración de servicio (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.configuracionServiciosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
