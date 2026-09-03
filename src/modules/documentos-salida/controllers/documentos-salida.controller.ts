import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  ParseIntPipe,
  Post,
  Query,
  StreamableFile,
} from '@nestjs/common';
import { ApiNotFoundResponse, ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  AnularDocSalidaDto,
  ConvertirGreDto,
  CreateDocSalidaDetalleDto,
  CreateDocSalidaDto,
  CrearDesdeVentaDto,
  FiltroDocSalidaDto,
  FinalizarRecargaDto,
  GenerarRecojoDocSalidaDto,
  RegistrarDireccionEntregaDto,
  SiguienteNumeroDocSalidaQueryDto,
} from '../dto/documentos-salida.dto';
import { DocumentosSalidaLogic } from '../logic/documentos-salida.logic';

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
  crear(@Body() dto: CreateDocSalidaDto) {
    return this.logic.crear(dto);
  }

  @Post('crear-desde-venta')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_CREAR)
  @ApiOperation({
    summary: 'Crear (y generar) una orden de salida ligada a una venta — no duplica el movimiento de inventario',
  })
  crearDesdeVenta(@Body() dto: CrearDesdeVentaDto) {
    return this.logic.crearDesdeVenta(dto);
  }

  @Post(':id/detalle')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Agregar una línea (producto o balón) — solo mientras está en BORRADOR' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  agregarDetalle(@Param('id', ParseIntPipe) id: number, @Body() dto: CreateDocSalidaDetalleDto) {
    return this.logic.agregarDetalle(id, dto);
  }

  @Delete('detalle/:detalleId')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Quitar una línea — solo mientras el documento está en BORRADOR' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminarDetalle(@Param('detalleId', ParseIntPipe) detalleId: number, @Body() dto: AuditoriaDto) {
    return this.logic.eliminarDetalle(detalleId, dto);
  }

  @Post(':id/generar')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Generar (BORRADOR → GENERADA): mueve inventario si no viene de una venta' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  generar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.logic.generar(id, dto);
  }

  @Post(':id/convertir-gre')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR)
  @ApiOperation({ summary: 'Completar datos SUNAT y reservar correlativo de guía de remisión' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  convertirAGre(@Param('id', ParseIntPipe) id: number, @Body() dto: ConvertirGreDto) {
    return this.logic.convertirAGre(id, dto);
  }

  @Post(':id/emitir-sunat')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR)
  @ApiOperation({ summary: 'Emitir a SUNAT (despatch/send)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  emitirSunat(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.logic.emitirSunat(id, dto);
  }

  @Post(':id/consultar-estado')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EMITIR)
  @ApiOperation({ summary: 'Consultar estado SUNAT (despatch/status)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  consultarEstado(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.logic.consultarEstado(id, dto);
  }

  @Post(':id/direccion-entrega')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Registrar dirección de entrega + coordenadas GPS (manual o desde dirección guardada del cliente)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  registrarDireccionEntrega(@Param('id', ParseIntPipe) id: number, @Body() dto: RegistrarDireccionEntregaDto) {
    return this.logic.registrarDireccionEntrega(id, dto);
  }

  @Post(':id/finalizar-recarga')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Registrar el retorno de una recarga en planta (compra, lote, P.H., balones)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  finalizarRecarga(@Param('id', ParseIntPipe) id: number, @Body() dto: FinalizarRecargaDto) {
    return this.logic.finalizarRecarga(id, dto);
  }

  @Post(':id/recojo')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_EDITAR)
  @ApiOperation({ summary: 'Generar recojo PROGRAMADO de los balones en planta externa' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  generarRecojo(@Param('id', ParseIntPipe) id: number, @Body() dto: GenerarRecojoDocSalidaDto) {
    return this.logic.generarRecojo(id, dto);
  }

  @Post(':id/anular')
  @Permisos(PermisoBanderas.DOCUMENTOS_SALIDA_ELIMINAR)
  @ApiOperation({ summary: 'Anular (revierte inventario si el documento lo movió por su cuenta)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  anular(@Param('id', ParseIntPipe) id: number, @Body() dto: AnularDocSalidaDto) {
    return this.logic.anular(id, dto);
  }
}
