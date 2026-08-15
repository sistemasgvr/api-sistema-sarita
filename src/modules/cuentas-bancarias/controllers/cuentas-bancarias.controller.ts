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
  CreateCuentaBancariaDto,
  FiltroCuentaBancariaDto,
  UpdateCuentaBancariaDto,
} from '../dto/cuentas-bancarias.dto';
import { CuentasBancariasLogic } from '../logic/cuentas-bancarias.logic';

@ApiTags('Cuentas Bancarias')
@Controller('cuentas-bancarias')
export class CuentasBancariasController {
  constructor(private readonly cuentasBancariasLogic: CuentasBancariasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CUENTAS_BANCARIAS_LISTAR)
  @ApiOperation({ summary: 'Listar cuentas bancarias' })
  listar(@Query() filtros: FiltroCuentaBancariaDto) {
    return this.cuentasBancariasLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CUENTAS_BANCARIAS_VER)
  @ApiOperation({ summary: 'Obtener cuenta bancaria por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.cuentasBancariasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CUENTAS_BANCARIAS_CREAR)
  @ApiOperation({ summary: 'Crear cuenta bancaria' })
  crear(@Body() dto: CreateCuentaBancariaDto) {
    return this.cuentasBancariasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CUENTAS_BANCARIAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar cuenta bancaria' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCuentaBancariaDto,
  ) {
    return this.cuentasBancariasLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CUENTAS_BANCARIAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar cuenta bancaria (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.cuentasBancariasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
