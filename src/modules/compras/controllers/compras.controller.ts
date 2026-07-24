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
import { ApiNotFoundResponse, ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateCompraDto,
  FiltroComprasDto,
  UpdateCompraDto,
} from '../dto/compras.dto';
import { ComprasLogic } from '../logic/compras.logic';

@ApiTags('Finanzas - Compras y Gastos')
@Controller('finanzas/compras')
export class ComprasController {
  constructor(private readonly comprasLogic: ComprasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.COMPRAS_LISTAR)
  @ApiOperation({ summary: 'Listar comprobantes de compra y gastos' })
  listar(@Query() filtros: FiltroComprasDto) {
    return this.comprasLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.COMPRAS_VER)
  @ApiOperation({ summary: 'Obtener comprobante de compra por ID' })
  @ApiOkResponse({ description: 'Comprobante obtenido correctamente' })
  @ApiNotFoundResponse({ description: 'El comprobante solicitado no existe o fue eliminado' })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.comprasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.COMPRAS_CREAR)
  @ApiOperation({ summary: 'Registrar nuevo comprobante de compra / gasto' })
  crear(@Body() dto: CreateCompraDto) {
    return this.comprasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({ summary: 'Actualizar comprobante de compra' })
  @ApiOkResponse({ description: 'Comprobante actualizado correctamente' })
  @ApiNotFoundResponse({ description: 'El comprobante que intenta actualizar no existe' })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateCompraDto,
  ) {
    return this.comprasLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.COMPRAS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar comprobante de compra (baja lógica)' })
  @ApiOkResponse({ description: 'Comprobante eliminado correctamente' })
  @ApiNotFoundResponse({ description: 'El comprobante que intenta eliminar no existe o ya fue dado de baja' })
  eliminar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.comprasLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}