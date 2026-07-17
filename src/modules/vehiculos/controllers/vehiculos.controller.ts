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
  CreateVehiculoDto,
  FiltroVehiculoDto,
  UpdateVehiculoDto,
} from '../dto/vehiculos.dto';
import { VehiculosLogic } from '../logic/vehiculos.logic';
import { Public } from '../../../common/decorators/public.decorator';

@ApiTags('Vehículos')
@Controller('vehiculos')
export class VehiculosController {
  constructor(private readonly vehiculosLogic: VehiculosLogic) {}

  @Get()
  @Public()
  //@Permisos(PermisoBanderas.VEHICULOS_LISTAR)
  @ApiOperation({ summary: 'Listar vehículos' })
  listar(@Query() filtros: FiltroVehiculoDto) {
    return this.vehiculosLogic.listar(filtros);
  }

  @Get(':id')
  @Public()
  //@Permisos(PermisoBanderas.VEHICULOS_VER)
  @ApiOperation({ summary: 'Obtener vehículo por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.vehiculosLogic.obtenerPorId(id);
  }

  @Post()
  @Public()
  //@Permisos(PermisoBanderas.VEHICULOS_CREAR)
  @ApiOperation({ summary: 'Crear vehículo' })
  crear(@Body() dto: CreateVehiculoDto) {
    return this.vehiculosLogic.crear(dto);
  }

  @Patch(':id')
  @Public()
  //@Permisos(PermisoBanderas.VEHICULOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar vehículo' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateVehiculoDto,
  ) {
    return this.vehiculosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Public()
  //@Permisos(PermisoBanderas.VEHICULOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar vehículo (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.vehiculosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
