import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import {
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import {
  ActualizarCompraCabeceraDto,
  ActualizarCompraDetalleDto,
  CreateCompraDetalleLineaDto,
  CreateCompraDto,
  FiltroComprasDto,
  RegistrarBalonesCompraDto,
  AgregarAdjuntoCompraDto,
} from '../dto/compras.dto';
import { ComprasLogic } from '../logic/compras.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

// El usuario de auditoría sale SIEMPRE del JWT: el body puede traerlo por
// compatibilidad, pero nunca decide quién firma la operación.
@ApiTags('Compras')
@Controller('/compras')
export class ComprasController {
  constructor(private readonly comprasLogic: ComprasLogic) {}

  @Get()
  @Permisos(PermisoBanderas.COMPRAS_LISTAR)
  @ApiOperation({ summary: 'Listar comprobantes de compra' })
  listar(@Query() filtros: FiltroComprasDto) {
    return this.comprasLogic.listar(filtros);
  }

  @Post(':id/balones')
  @Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({
    summary:
      'Registra los cilindros comprados: los da de alta en el libro y genera un movimiento por cada uno',
  })
  registrarBalones(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarBalonesCompraDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.registrarBalones(id, dto);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.COMPRAS_VER)
  @ApiOperation({ summary: 'Obtener comprobante de compra por ID' })
  @ApiOkResponse({ description: 'Comprobante obtenido correctamente' })
  @ApiNotFoundResponse({
    description: 'El comprobante solicitado no existe o fue eliminado',
  })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.comprasLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.COMPRAS_CREAR)
  @ApiOperation({ summary: 'Registrar nuevo comprobante de compra' })
  crear(@Body() dto: CreateCompraDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.COMPRAS_EDITAR)
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
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.actualizarCabecera(id, dto);
  }

  @Post(':id/detalle')
  @Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({ summary: 'Agregar línea a una compra existente' })
  @ApiOkResponse({ description: 'Línea agregada correctamente' })
  @ApiNotFoundResponse({ description: 'La compra indicada no existe' })
  crearDetalle(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateCompraDetalleLineaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.crearDetalle(id, dto);
  }

  @Patch('detalle/:idDetalle')
  @Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({
    summary:
      'Actualizar cantidad/precio de una línea (ajusta stock diferencial si afecta_stock)',
  })
  @ApiOkResponse({ description: 'Línea actualizada correctamente' })
  @ApiNotFoundResponse({ description: 'El detalle indicado no existe' })
  actualizarDetalle(
    @Param('idDetalle', ParseIntPipe) idDetalle: number,
    @Body() dto: ActualizarCompraDetalleDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.actualizarDetalle(idDetalle, dto);
  }

  @Delete('detalle/:idDetalle')
  @Permisos(PermisoBanderas.COMPRAS_EDITAR)
  @ApiOperation({ summary: 'Eliminar una línea de detalle de compra' })
  @ApiOkResponse({ description: 'Línea eliminada correctamente' })
  @ApiNotFoundResponse({ description: 'El detalle indicado no existe' })
  eliminarDetalle(
    @Param('idDetalle', ParseIntPipe) idDetalle: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.eliminarDetalle(idDetalle, dto.idUsuarioAuditoria);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.COMPRAS_ELIMINAR)
  @ApiOperation({
    summary: 'Anular comprobante de compra completo (revierte stock)',
  })
  @ApiOkResponse({ description: 'Comprobante anulado correctamente' })
  @ApiNotFoundResponse({
    description: 'El comprobante que intenta anular no existe o ya fue anulado',
  })
  anular(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.anular(id, dto.idUsuarioAuditoria);
  }

  // ── Adjuntos (factura del proveedor, guía, foto) ──
  // El archivo se sube antes con POST /storage/upload en la carpeta compras/.

  @Get(':id/adjuntos')
  @Permisos(PermisoBanderas.COMPRAS_VER)
  @ApiOperation({ summary: 'Listar archivos adjuntos de la compra' })
  listarAdjuntos(@Param('id', ParseIntPipe) id: number) {
    return this.comprasLogic.listarAdjuntos(id);
  }

  @Post(':id/adjuntos')
  @Permisos(PermisoBanderas.COMPRAS_VER)
  @ApiOperation({ summary: 'Adjuntar a la compra un archivo ya subido' })
  agregarAdjunto(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AgregarAdjuntoCompraDto,
    @Req() req: AuthRequest,
  ) {
    exigirCrearOEditarCompra(req.user);
    dto.idUsuarioAuditoria = req.user.id;
    return this.comprasLogic.agregarAdjunto(id, dto);
  }

  @Delete(':id/adjuntos/:idAdjunto')
  @Permisos(PermisoBanderas.COMPRAS_VER)
  @ApiOperation({ summary: 'Quitar un adjunto de la compra' })
  eliminarAdjunto(
    @Param('id', ParseIntPipe) id: number,
    @Param('idAdjunto', ParseIntPipe) idAdjunto: number,
    @Req() req: AuthRequest,
  ) {
    exigirCrearOEditarCompra(req.user);
    return this.comprasLogic.eliminarAdjunto(id, idAdjunto, req.user.id);
  }
}

/** Adjuntar es parte de registrar la compra: basta con crear O editar. */
function exigirCrearOEditarCompra(user: AuthenticatedUser) {
  const permisos = user.permisos ?? [];
  if (
    permisos.includes(PermisoBanderas.AUTH_TODO) ||
    permisos.includes(PermisoBanderas.COMPRAS_CREAR) ||
    permisos.includes(PermisoBanderas.COMPRAS_EDITAR)
  ) {
    return;
  }
  throw new ForbiddenException('Necesitas permiso para crear o editar compras');
}
