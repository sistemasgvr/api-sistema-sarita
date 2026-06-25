import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Public } from '../../../common/decorators/public.decorator';
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { CreateSesionDto, ValidarSesionDto } from '../dto/create-sesion.dto';
import { FiltroSesionesDto } from '../dto/sesiones.dto';
import { SesionesLogic } from '../logic/sesiones.logic';

@ApiTags('Auth - Sesiones')
@Controller('auth/sesiones')
export class SesionesController {
  constructor(private readonly sesionesLogic: SesionesLogic) {}

  @Get()
  @ApiOperation({ summary: 'Listar sesiones' })
  listar(@Query() filtros: FiltroSesionesDto) {
    return this.sesionesLogic.listar(filtros);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener sesión por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.sesionesLogic.obtenerPorId(id);
  }

  @Post()
  @ApiOperation({ summary: 'Crear sesión' })
  crear(@Body() dto: CreateSesionDto) {
    return this.sesionesLogic.crear(dto);
  }

  @Public()
  @Post('validar')
  @ApiOperation({ summary: 'Validar token de sesión activa' })
  validar(@Body() dto: ValidarSesionDto) {
    return this.sesionesLogic.validar(dto);
  }

  @Patch(':id/cerrar')
  @ApiOperation({ summary: 'Cerrar sesión' })
  cerrar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.sesionesLogic.cerrar(id, dto.idUsuarioAuditoria);
  }
}
