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
import {
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  ActualizarCompraCabeceraDto,
  CreateCompraDetalleLineaDto,
  CreateCompraDto,
  FiltroComprasDto,
} from '../dto/compras.dto';
import { ComprasLogic } from '../logic/compras.logic';
import { Public } from 'src/common/decorators/public.decorator';

@ApiTags('Compras')
@Controller('/compras')
export class ComprasController {
  constructor(private readonly comprasLogic: ComprasLogic) {}

  @Get()
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_LISTAR)
  @ApiOperation({ summary: 'Listar comprobantes de compra' })
  listar(@Query() filtros: FiltroComprasDto) {
    return this.comprasLogic.listar(filtros);
  }

  @Get(':id')
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_VER)
  @ApiOperation({ summary: 'Obtener comprobante de compra por ID' })
  @ApiOkResponse({ description: 'Comprobante obtenido correctamente' })
  @ApiNotFoundResponse({
    description: 'El comprobante solicitado no existe o fue eliminado',
  })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.comprasLogic.obtenerPorId(id);
  }

  @Post()
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_CREAR)
  @ApiOperation({ summary: 'Registrar nuevo comprobante de compra' })
  crear(@Body() dto: CreateCompraDto) {
    return this.comprasLogic.crear(dto);
  }

  @Patch(':id')
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({
    summary:
      'Actualizar cabecera (glosa, condición pago, categoría gasto, declarar sunat)',
  })
  @ApiOkResponse({ description: 'Cabecera actualizada correctamente' })
  @ApiNotFoundResponse({
    description: 'El comprobante que intenta actualizar no existe',
  })
  actualizarCabecera(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarCompraCabeceraDto,
  ) {
    return this.comprasLogic.actualizarCabecera(id, dto);
  }

  @Post(':id/detalle')
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({ summary: 'Agregar línea a una compra existente' })
  @ApiOkResponse({ description: 'Línea agregada correctamente' })
  @ApiNotFoundResponse({ description: 'La compra indicada no existe' })
  crearDetalle(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateCompraDetalleLineaDto,
  ) {
    return this.comprasLogic.crearDetalle(id, dto);
  }

  @Delete('detalle/:idDetalle')
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({ summary: 'Eliminar una línea de detalle de compra' })
  @ApiOkResponse({ description: 'Línea eliminada correctamente' })
  @ApiNotFoundResponse({ description: 'El detalle indicado no existe' })
  eliminarDetalle(
    @Param('idDetalle', ParseIntPipe) idDetalle: number,
    @Body() dto: AuditoriaDto,
  ) {
    return this.comprasLogic.eliminarDetalle(idDetalle, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Public()
  //@Permisos(PermisoBanderas.COMPRAS_ELIMINAR)
  @ApiOperation({
    summary: 'Anular comprobante de compra completo (revierte stock)',
  })
  @ApiOkResponse({ description: 'Comprobante anulado correctamente' })
  @ApiNotFoundResponse({
    description: 'El comprobante que intenta anular no existe o ya fue anulado',
  })
  anular(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.comprasLogic.anular(id, dto.idUsuarioAuditoria);
  }
}
