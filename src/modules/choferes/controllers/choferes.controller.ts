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
  CreateChoferDto,
  FiltroChoferDto,
  UpdateChoferDto,
} from '../dto/choferes.dto';
import { ChoferesLogic } from '../logic/choferes.logic';

@ApiTags('Choferes')
@Controller('choferes')
export class ChoferesController {
  constructor(private readonly choferesLogic: ChoferesLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CHOFERES_LISTAR)
  @ApiOperation({ summary: 'Listar choferes' })
  listar(@Query() filtros: FiltroChoferDto) {
    return this.choferesLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CHOFERES_VER)
  @ApiOperation({ summary: 'Obtener chofer por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.choferesLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CHOFERES_CREAR)
  @ApiOperation({ summary: 'Crear chofer' })
  crear(@Body() dto: CreateChoferDto) {
    return this.choferesLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CHOFERES_EDITAR)
  @ApiOperation({ summary: 'Actualizar chofer' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateChoferDto,
  ) {
    return this.choferesLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CHOFERES_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar chofer (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.choferesLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
