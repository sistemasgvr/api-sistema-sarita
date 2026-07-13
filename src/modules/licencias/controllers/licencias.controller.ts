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
  CreateLicenciaDto,
  FiltroLicenciaDto,
  UpdateLicenciaDto,
} from '../dto/licencias.dto';
import { LicenciasLogic } from '../logic/licencias.logic';
import { Public } from 'src/common/decorators/public.decorator';

@ApiTags('Licencias')
@Controller('licencias')
export class LicenciasController {
  constructor(private readonly licenciasLogic: LicenciasLogic) {}

  @Get()
  @Public()
  //@Permisos(PermisoBanderas.LICENCIAS_LISTAR)
  @ApiOperation({ summary: 'Listar licencias de choferes' })
  listar(@Query() filtros: FiltroLicenciaDto) {
    return this.licenciasLogic.listar(filtros);
  }

  @Get(':id')
  @Public()
  //@Permisos(PermisoBanderas.LICENCIAS_VER)
  @ApiOperation({ summary: 'Obtener licencia por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.licenciasLogic.obtenerPorId(id);
  }

  @Post()
  @Public()
  //@Permisos(PermisoBanderas.LICENCIAS_CREAR)
  @ApiOperation({ summary: 'Crear licencia para un chofer' })
  crear(@Body() dto: CreateLicenciaDto) {
    return this.licenciasLogic.crear(dto);
  }

  @Patch(':id')
  @Public()
  //@Permisos(PermisoBanderas.LICENCIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar licencia' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateLicenciaDto,
  ) {
    return this.licenciasLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Public()
  //@Permisos(PermisoBanderas.LICENCIAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar licencia (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.licenciasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
