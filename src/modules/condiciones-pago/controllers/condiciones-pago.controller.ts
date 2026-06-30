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
  CreateCondicionPagoDto,
  UpdateCondicionPagoDto,
} from '../dto/condiciones-pago.dto';
import { CondicionesPagoLogic } from '../logic/condiciones-pago.logic';

@ApiTags('Configuracion - Condiciones de Pago')
@Controller('configuracion/condiciones-pago')
export class CondicionesPagoController {
  constructor(private readonly condicionesPagoLogic: CondicionesPagoLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CONDICIONES_PAGO_LISTAR)
  @ApiOperation({ summary: 'Listar condiciones de pago' })
  listar(@Query() filtros: FiltroPaginacionDto) {
    return this.condicionesPagoLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CONDICIONES_PAGO_VER)
  @ApiOperation({ summary: 'Obtener condición de pago por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.condicionesPagoLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CONDICIONES_PAGO_CREAR)
  @ApiOperation({ summary: 'Crear condición de pago' })
  crear(@Body() dto: CreateCondicionPagoDto) {
    return this.condicionesPagoLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CONDICIONES_PAGO_EDITAR)
  @ApiOperation({ summary: 'Actualizar condición de pago' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCondicionPagoDto,
  ) {
    return this.condicionesPagoLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CONDICIONES_PAGO_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar condición de pago (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.condicionesPagoLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
