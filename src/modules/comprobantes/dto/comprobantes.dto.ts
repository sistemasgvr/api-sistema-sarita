import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  Min,
  IsPositive,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { MONEY_NUMBER_OPTIONS } from '../../../common/constants/money';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class PdfComprobanteQueryDto {
  @ApiPropertyOptional({
    enum: ['a4', 'ticket'],
    default: 'a4',
    description: 'Formato de representación impresa: A4 o ticketera 80mm',
  })
  @IsOptional()
  @IsIn(['a4', 'ticket'])
  formato?: 'a4' | 'ticket';
}

export class FiltroComprobantesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoComprobante?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoSunat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serie?: string;

  @ApiPropertyOptional({
    description: '1 = solo activos (default), 0 = solo inactivos/anulados, omitir/null = todos',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  soloActivos?: number;
}

export class SiguienteNumeroQueryDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idTipoComprobante!: number;

  @ApiProperty()
  @MaxLength(10)
  @IsString()
  @IsNotEmpty()
  serie!: string;
}

export class ComprobanteDetalleDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idProducto!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  cantidad!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  @IsNotEmpty()
  precioUnitario!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  descuento?: number;

  @ApiPropertyOptional({ default: 18 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  porcentajeIgv?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAfectacionIgv?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  item?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidadCilindro?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoCilindro?: number;
}

export class ComprobanteCuotaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  numeroCuota!: number;

  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fechaVencimiento!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  @IsNotEmpty()
  monto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  montoPagado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;
}

export class EfectoPosGarantiaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  @IsPositive()
  monto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  cantidadVenta?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class EfectoPosRecargaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idProducto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idBalonOrigen?: number;
}

export class EfectoPosPrestamoDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idTipoPrestamo!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaSalida?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRetornoPactada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  titulo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idEstado?: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaEntregado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPrestamo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacionDetalle?: string;

  @ApiPropertyOptional({ type: EfectoPosGarantiaDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectoPosGarantiaDto)
  garantia?: EfectoPosGarantiaDto;
}

export class EfectoPosAlquilerPeriodoDto {
  @ApiProperty()
  @IsDateString()
  fechaInicio!: string;

  @ApiProperty()
  @IsDateString()
  fechaFin!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  monto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class EfectoPosAlquilerDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiProperty()
  @IsDateString()
  fechaInicio!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFinPactada?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  tarifaDiaria?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  totalCobrado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProductoRegulador?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProductoStock?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional({ type: EfectoPosAlquilerPeriodoDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectoPosAlquilerPeriodoDto)
  periodo?: EfectoPosAlquilerPeriodoDto;

  @ApiPropertyOptional({ type: EfectoPosGarantiaDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectoPosGarantiaDto)
  garantia?: EfectoPosGarantiaDto;
}

export class EfectoPosMantenimientoDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiProperty()
  @IsDateString()
  fechaIngreso!: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idTipoMantenimiento?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  costo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class EfectoPosBajaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idMotivoBaja!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  montoVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaBaja?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  aprobar?: boolean;
}

export class EfectosPosDto {
  @ApiPropertyOptional({ type: [EfectoPosRecargaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosRecargaDto)
  recargas?: EfectoPosRecargaDto[];

  @ApiPropertyOptional({ type: [EfectoPosPrestamoDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosPrestamoDto)
  prestamos?: EfectoPosPrestamoDto[];

  @ApiPropertyOptional({ type: [EfectoPosAlquilerDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosAlquilerDto)
  alquileres?: EfectoPosAlquilerDto[];

  @ApiPropertyOptional({ type: [EfectoPosMantenimientoDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosMantenimientoDto)
  mantenimientos?: EfectoPosMantenimientoDto[];

  @ApiPropertyOptional({ type: [EfectoPosBajaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosBajaDto)
  bajas?: EfectoPosBajaDto[];

  @ApiPropertyOptional({
    description:
      'Si es true y hay préstamo de cilindro, intenta generar GRE remitente. Por defecto no se genera.',
  })
  @IsOptional()
  @IsBoolean()
  generarGre?: boolean;
}

/** Una línea de cobro de la venta (Fase 3: cobro multi-medio). */
export class ComprobantePagoDto {
  @ApiProperty({ example: 265, description: 'ID de opción de lista MedioPago' })
  @Type(() => Number)
  @IsInt()
  idMedioPago!: number;

  @ApiPropertyOptional({
    example: 50.0,
    description:
      'Monto cobrado por este medio. En una lista de un solo pago puede omitirse: se toma el total del comprobante.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @IsPositive()
  monto?: number;

  @ApiPropertyOptional({
    example: 16,
    description:
      'Cuenta bancaria de la EMPRESA que recibe el dinero. Obligatoria cuando el medio de pago no es efectivo.',
  })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idCuentaBancaria?: number;

  @ApiPropertyOptional({ example: 'OP-00123' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  numeroOperacion?: string;

  @ApiPropertyOptional({ example: 'Yape del titular' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  referencia?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class CreateComprobantesDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idTipoComprobante!: number;

  @ApiProperty()
  @MaxLength(10)
  @IsString()
  @IsNotEmpty()
  serie!: string;

  @ApiPropertyOptional({ description: 'Si se omite, se asigna automáticamente' })
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numero?: string;

  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idCliente!: number;

  @ApiProperty({ type: [ComprobanteDetalleDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ComprobanteDetalleDto)
  detalles!: ComprobanteDetalleDto[];

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoOperacionSunat?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteOrigen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMotivoNota?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoMovimiento?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional({ default: 3.5 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  tipoCambio?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idSucursal?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCondicionPago?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMoneda?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMedioPago?: number;

  @ApiPropertyOptional({
    type: [ComprobantePagoDto],
    description:
      'Desglose del cobro por medio de pago. La suma debe igualar el total del comprobante. ' +
      'Omitir para dejar el comportamiento anterior (un solo medio en la cabecera).',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComprobantePagoDto)
  pagos?: ComprobantePagoDto[];

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  glosa?: string;

  @ApiPropertyOptional()
  @MaxLength(1000)
  @IsOptional()
  @IsString()
  observaciones?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  periodoContable?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  operacion?: string;

  @ApiPropertyOptional({
    description:
      'Pestaña POS de emisión: accesorios|recarga|medicinal|industrial|mantenimiento',
    example: 'accesorios',
  })
  @MaxLength(30)
  @IsOptional()
  @IsString()
  origenPos?: string;

  @ApiPropertyOptional({
    type: EfectosPosDto,
    description:
      'Efectos POS (recarga, préstamo, alquiler, garantía, mantenimiento, baja) en la misma transacción del CPE',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectosPosDto)
  efectosPos?: EfectosPosDto;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional({ type: [ComprobanteCuotaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComprobanteCuotaDto)
  cuotas?: ComprobanteCuotaDto[];
}

export class UpdateComprobantesDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional({ type: [ComprobanteDetalleDto] })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ComprobanteDetalleDto)
  detalles?: ComprobanteDetalleDto[];

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoOperacionSunat?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteOrigen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMotivoNota?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoMovimiento?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  tipoCambio?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idSucursal?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCondicionPago?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMoneda?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMedioPago?: number;

  @ApiPropertyOptional({
    type: [ComprobantePagoDto],
    description:
      'Desglose del cobro por medio de pago. La suma debe igualar el total del comprobante. ' +
      'Omitir para dejar el comportamiento anterior (un solo medio en la cabecera).',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComprobantePagoDto)
  pagos?: ComprobantePagoDto[];

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  glosa?: string;

  @ApiPropertyOptional()
  @MaxLength(1000)
  @IsOptional()
  @IsString()
  observaciones?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  periodoContable?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  operacion?: string;

  @ApiPropertyOptional({
    description:
      'Pestaña POS de emisión: accesorios|recarga|medicinal|industrial|mantenimiento',
    example: 'accesorios',
  })
  @MaxLength(30)
  @IsOptional()
  @IsString()
  origenPos?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional({ type: [ComprobanteCuotaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComprobanteCuotaDto)
  cuotas?: ComprobanteCuotaDto[];
}

/** Una línea de cobro a completar tras la venta (Fase 3). */
export class RegistrarCobroLineaDto {
  @ApiProperty({ example: 25, description: 'ID de la línea de ven_comprobante_pago' })
  @Type(() => Number)
  @IsInt()
  idPago!: number;

  @ApiPropertyOptional({ example: 'YAPE-4471' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  numeroOperacion?: string;

  @ApiPropertyOptional({ example: 'Yape del titular' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  referencia?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({
    example: 16,
    description: 'Cambiar la cuenta de la empresa. Omitir para conservar la actual.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCuentaBancaria?: number;
}

export class RegistrarCobroComprobanteDto extends AuditoriaDto {
  @ApiProperty({ type: [RegistrarCobroLineaDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RegistrarCobroLineaDto)
  pagos!: RegistrarCobroLineaDto[];
}

export class AnularComprobanteDto extends AuditoriaDto {
  @ApiProperty({
    example: 'ERROR EN EL CLIENTE / CANTIDAD',
    description: 'Motivo de la comunicación de baja ante SUNAT',
  })
  @MaxLength(250)
  @IsString()
  @IsNotEmpty()
  motivo!: string;
}

export class PreviewResumenDiarioQueryDto {
  @ApiProperty({ example: '2026-07-13' })
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;
}

export class FiltroResumenDiarioDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoSunat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class EstadoResumenDiarioQueryDto {
  @ApiProperty({ example: '20260713123456' })
  @IsString()
  @IsNotEmpty()
  ticket!: string;
}

export class EnviarResumenDiarioDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-07-13' })
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;

  @ApiPropertyOptional({
    example: '001',
    description: 'Correlativo del resumen del día (3 dígitos). Por defecto el siguiente disponible.',
  })
  @MaxLength(10)
  @IsOptional()
  @IsString()
  correlativo?: string;

  @ApiPropertyOptional({
    type: [Number],
    description: 'Si se omite, incluye todas las boletas/NC familia B de la fecha',
  })
  @IsOptional()
  @IsArray()
  @Type(() => Number)
  @IsNumber({}, { each: true })
  idsComprobante?: number[];
}

export class RegistrarRespuestaSunatDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoSunat?: number;

  @ApiPropertyOptional()
  @MaxLength(100)
  @IsOptional()
  @IsString()
  ticketSunat?: string;

  @ApiPropertyOptional()
  @MaxLength(200)
  @IsOptional()
  @IsString()
  hashDocumento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  xmlFirmado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cdrRespuesta?: string;
}
