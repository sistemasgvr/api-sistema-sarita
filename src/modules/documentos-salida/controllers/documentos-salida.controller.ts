import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  StreamableFile,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import type { AuthenticatedUser } from '../../../common/interfaces/authenticated-user.interface';
import {
  ActualizarDocSalidaDetalleDto,
  ActualizarDocSalidaDto,
  AnularDocSalidaDto,
  ConvertirGreDto,
  CreateDocSalidaDetalleDto,
  CreateDocSalidaDto,
  CrearDesdeVentaDto,
  FiltroDocSalidaDto,
  FinalizarRecargaDto,
  RegistrarDireccionEntregaDto,
  SeriesGreQueryDto,
  SiguienteNumeroDocSalidaQueryDto,
  ActualizarTrasladoDto,
} from '../dto/documentos-salida.dto';
import { DocumentosSalidaLogic } from '../logic/documentos-salida.logic';

type AuthRequest = Request & { user: AuthenticatedUser };

@ApiTags('Documentos de salida')
@Controller('documentos-salida')
export class DocumentosSalidaController {
  constructor(private readonly logic: DocumentosSalidaLogic) {}

  @Get()
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_LISTAR)
  @ApiOperation({ summary: 'Listar documentos de salida (órdenes, recargas planta, guías)' })
  listar(@Query() filtros: FiltroDocSalidaDto) {
    return this.logic.listar(filtros);
  }

  @Get('catalogos')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_LISTAR)
  @ApiOperation({ summary: 'Catálogos para el formulario' })
  obtenerCatalogos() {
    return this.logic.obtenerCatalogos();
  }

  @Get('siguiente-numero')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_CREAR)
  @ApiOperation({ summary: 'Siguiente correlativo interno por sucursal (OS-xx-aaaa-nnnnnn)' })
  obtenerSiguienteNumero(@Query() query: SiguienteNumeroDocSalidaQueryDto) {
    return this.logic.obtenerSiguienteNumero(query);
  }

  @Get('series-gre')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_LISTAR)
  @ApiOperation({
    summary: 'Series de guía de remisión por tipo (T### remitente / V### transportista) con su siguiente correlativo',
  })
  listarSeriesGre(@Query() query: SeriesGreQueryDto) {
    return this.logic.listarSeriesGre(query);
  }

  @Get(':id/pdf')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_VER)
  @ApiOperation({ summary: 'Generar PDF A4 (orden interna o guía de remisión)' })
  @ApiProduces('application/pdf')
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  @Header('Content-Type', 'application/pdf')
  async generarPdf(@Param('id', ParseIntPipe) id: number) {
    const { buffer, filename } = await this.logic.generarPdf(id);
    return new StreamableFile(buffer, { type: 'application/pdf', disposition: `inline; filename="${filename}"` });
  }

  @Get(':id')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_VER)
  @ApiOperation({ summary: 'Obtener documento de salida por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtener(@Param('id', ParseIntPipe) id: number) {
    return this.logic.obtener(id);
  }

  @Post()
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_CREAR)
  @ApiOperation({ summary: 'Crear documento de salida (orden interna, recarga planta, retorno, traslado)' })
  crear(@Body() dto: CreateDocSalidaDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.crear(dto);
  }

  @Post('crear-desde-venta')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_CREAR)
  @ApiOperation({
    summary: 'Crear (y generar) una orden de salida ligada a una venta — no duplica el movimiento de inventario',
  })
  crearDesdeVenta(@Body() dto: CrearDesdeVentaDto, @Req() req: AuthRequest) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.crearDesdeVenta(dto);
  }

  @Post(':id/detalle')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Agregar una línea (producto o balón) — solo mientras está en BORRADOR' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  agregarDetalle(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateDocSalidaDetalleDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.agregarDetalle(id, dto);
  }

  @Patch('detalle/:detalleId')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({
    summary: 'Corregir cantidad o glosa de una línea — solo mientras está en BORRADOR',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizarDetalle(
    @Param('detalleId', ParseIntPipe) detalleId: number,
    @Body() dto: ActualizarDocSalidaDetalleDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizarDetalle(detalleId, dto);
  }

  @Delete('detalle/:detalleId')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Quitar una línea — solo mientras el documento está en BORRADOR' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminarDetalle(
    @Param('detalleId', ParseIntPipe) detalleId: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.eliminarDetalle(detalleId, dto);
  }

  @Patch(':id/traslado')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({
    summary:
      'Actualiza motivo, modalidad, peso y bultos — los datos de traslado que imprime el PDF',
  })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizarTraslado(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarTrasladoDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizarTraslado(id, dto);
  }

  // Después de las rutas PATCH con segmento fijo ('detalle/:detalleId',
  // ':id/traslado'): declarada antes, ParseIntPipe intentaría leer 'detalle'
  // como id y esas rutas devolverían 400.
  @Patch(':id')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Corregir las observaciones de la orden' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ActualizarDocSalidaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.actualizar(id, dto);
  }

  @Post(':id/generar')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Generar (BORRADOR → GENERADA): mueve inventario si no viene de una venta' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  generar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.generar(id, dto);
  }

  @Post(':id/convertir-gre')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR)
  @ApiOperation({ summary: 'Completar datos SUNAT y reservar correlativo de guía de remisión' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  convertirAGre(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: ConvertirGreDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.convertirAGre(id, dto);
  }

  @Post(':id/emitir-sunat')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR)
  @ApiOperation({ summary: 'Emitir a SUNAT (despatch/send)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  emitirSunat(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.emitirSunat(id, dto);
  }

  @Post(':id/consultar-estado')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR)
  @ApiOperation({ summary: 'Consultar estado SUNAT (despatch/status)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  consultarEstado(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AuditoriaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.consultarEstado(id, dto);
  }

  @Post(':id/direccion-entrega')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Registrar dirección de entrega + coordenadas GPS (manual o desde dirección guardada del cliente)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  registrarDireccionEntrega(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: RegistrarDireccionEntregaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.registrarDireccionEntrega(id, dto);
  }

  @Post(':id/finalizar-recarga')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Registrar el retorno de una recarga en planta (compra, lote, P.H., balones)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  finalizarRecarga(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: FinalizarRecargaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.finalizarRecarga(id, dto);
  }

  @Post(':id/anular')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_ELIMINAR)
  @ApiOperation({ summary: 'Anular (revierte inventario si el documento lo movió por su cuenta)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anular(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: AnularDocSalidaDto,
    @Req() req: AuthRequest,
  ) {
    dto.idUsuarioAuditoria = req.user.id;
    return this.logic.anular(id, dto);
  }
}
