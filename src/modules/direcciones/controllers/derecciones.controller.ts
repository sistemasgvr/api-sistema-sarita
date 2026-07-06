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
//import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
//import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { Public } from '../../../common/decorators/public.decorator';

import { DireccionesLogic } from '../logic/direcciones.logic';
import {
  CreateDireccionDto,
  FiltroDireccionesDto,
  UpdateDireccionDto,
} from '../dto/filtros-direcciones.dto';

@ApiTags('Direcciones')
@Controller('direcciones')
export class DireccionesController {
  constructor(private readonly direccionesLogic: DireccionesLogic) {}

  @Get()
  @Public()
  //@Permisos(PermisoBanderas.DIRECCIONES_LISTAR)
  @ApiOperation({ summary: 'Listar direcciones de clientes/proveedores' })
  listar(@Query() filtros: FiltroDireccionesDto) {
    return this.direccionesLogic.listar(filtros);
  }

  @Get(':id')
  @Public()
  //@Permisos(PermisoBanderas.DIRECCIONES_VER)
  @ApiOperation({ summary: 'Obtener dirección por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.direccionesLogic.obtenerPorId(id);
  }

  @Post()
  @Public()
  //@Permisos(PermisoBanderas.DIRECCIONES_CREAR)
  @ApiOperation({ summary: 'Crear nueva dirección para un cliente' })
  crear(@Body() dto: CreateDireccionDto) {
    return this.direccionesLogic.crear(dto);
  }

  @Patch(':id')
  @Public()
  //@Permisos(PermisoBanderas.DIRECCIONES_EDITAR)
  @ApiOperation({ summary: 'Actualizar dirección' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateDireccionDto,
  ) {
    return this.direccionesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Public()
  //@Permisos(PermisoBanderas.DIRECCIONES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar dirección (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.direccionesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
