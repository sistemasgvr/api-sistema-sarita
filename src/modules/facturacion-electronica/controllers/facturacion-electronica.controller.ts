import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiBody, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import {
  FacturacionComprobanteStatusDto,
  FacturacionLoginDto,
  FacturacionTicketStatusDto,
} from '../dto/facturacion-electronica.dto';
import { FacturacionElectronicaLogic } from '../logic/facturacion-electronica.logic';

@ApiTags('Facturación electrónica')
@Controller('facturacion-electronica')
export class FacturacionElectronicaController {
  constructor(private readonly logic: FacturacionElectronicaLogic) {}

  @Get('estado')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Estado de la integración APIsPERU Facturación' })
  obtenerEstado() {
    return this.logic.obtenerEstado();
  }

  @Get('conexion')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Verificar conexión con APIsPERU Facturación' })
  verificarConexion() {
    return this.logic.verificarConexion();
  }

  @Post('auth/login')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Iniciar sesión en APIsPERU (token 24h)' })
  iniciarSesion(@Body() dto: FacturacionLoginDto) {
    return this.logic.iniciarSesion(dto);
  }

  @Get('empresas')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_LISTAR)
  @ApiOperation({ summary: 'Listar empresas emisoras en APIsPERU' })
  listarEmpresas() {
    return this.logic.listarEmpresas();
  }

  @Get('empresas/:companyId')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Obtener empresa emisora en APIsPERU' })
  obtenerEmpresa(@Param('companyId', ParseIntPipe) companyId: number) {
    return this.logic.obtenerEmpresa(companyId);
  }

  @Post('comprobantes/enviar')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Enviar factura o boleta a SUNAT (invoice/send)' })
  @ApiBody({ schema: { type: 'object', additionalProperties: true } })
  enviarFacturaBoleta(@Body() payload: Record<string, unknown>) {
    return this.logic.enviarFacturaBoleta(payload);
  }

  @Post('comprobantes/xml')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Generar XML de factura o boleta (invoice/xml)' })
  @ApiBody({ schema: { type: 'object', additionalProperties: true } })
  generarXmlFacturaBoleta(@Body() payload: Record<string, unknown>) {
    return this.logic.generarXmlFacturaBoleta(payload);
  }

  @Get('comprobantes/estado')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Consultar CDR de factura o boleta (invoice/status)' })
  consultarEstadoFacturaBoleta(@Query() query: FacturacionComprobanteStatusDto) {
    return this.logic.consultarEstadoFacturaBoleta(query);
  }

  @Post('notas/enviar')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Enviar nota de crédito/débito (note/send)' })
  @ApiBody({ schema: { type: 'object', additionalProperties: true } })
  enviarNota(@Body() payload: Record<string, unknown>) {
    return this.logic.enviarNota(payload);
  }

  @Post('resumenes/enviar')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Enviar resumen diario de boletas (summary/send)' })
  @ApiBody({ schema: { type: 'object', additionalProperties: true } })
  enviarResumenDiario(@Body() payload: Record<string, unknown>) {
    return this.logic.enviarResumenDiario(payload);
  }

  @Get('resumenes/estado')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Consultar estado de resumen diario (summary/status)' })
  consultarEstadoResumen(@Query() query: FacturacionTicketStatusDto) {
    return this.logic.consultarEstadoResumen(query);
  }

  @Post('bajas/enviar')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Enviar comunicación de baja (voided/send)' })
  @ApiBody({ schema: { type: 'object', additionalProperties: true } })
  enviarComunicacionBaja(@Body() payload: Record<string, unknown>) {
    return this.logic.enviarComunicacionBaja(payload);
  }

  @Get('bajas/estado')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Consultar estado de comunicación de baja (voided/status)' })
  consultarEstadoComunicacionBaja(@Query() query: FacturacionTicketStatusDto) {
    return this.logic.consultarEstadoComunicacionBaja(query);
  }

  @Post('guias/enviar')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({ summary: 'Enviar guía de remisión (despatch/send)' })
  @ApiBody({ schema: { type: 'object', additionalProperties: true } })
  enviarGuiaRemision(@Body() payload: Record<string, unknown>) {
    return this.logic.enviarGuiaRemision(payload);
  }

  @Get('guias/estado')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({
    summary: 'Consultar estado de guía de remisión (despatch/status por ticket)',
  })
  consultarEstadoGuiaRemision(@Query() query: FacturacionTicketStatusDto) {
    return this.logic.consultarEstadoGuiaRemision(query);
  }
}
