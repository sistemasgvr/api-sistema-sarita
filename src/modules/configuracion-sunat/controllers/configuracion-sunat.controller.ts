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
  CreateConfiguracionSunatDto,
  FiltroConfiguracionSunatDto,
  UpdateConfiguracionSunatDto,
} from '../dto/configuracion-sunat.dto';
import { ConfiguracionSunatLogic } from '../logic/configuracion-sunat.logic';

@ApiTags('Configuracion - SUNAT')
@Controller('configuracion/sunat')
export class ConfiguracionSunatController {
  constructor(
    private readonly configuracionSunatLogic: ConfiguracionSunatLogic,
  ) {}

  @Get()
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_LISTAR)
  @ApiOperation({ summary: 'Listar configuraciones SUNAT' })
  listar(@Query() filtros: FiltroConfiguracionSunatDto) {
    return this.configuracionSunatLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Obtener configuración SUNAT por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.configuracionSunatLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_CREAR)
  @ApiOperation({ summary: 'Crear configuración SUNAT' })
  crear(@Body() dto: CreateConfiguracionSunatDto) {
    return this.configuracionSunatLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Actualizar configuración SUNAT' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateConfiguracionSunatDto,
  ) {
    return this.configuracionSunatLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar configuración SUNAT (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.configuracionSunatLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
